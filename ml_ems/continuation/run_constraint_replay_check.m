function report = run_constraint_replay_check(project_root,reference_balance_soft)
% Capture actual safety inputs, then verify all twelve residual terms offline.
if nargin<1
    project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2, reference_balance_soft=false; end
validateattributes(reference_balance_soft,{'logical'},{'scalar'});
addpath(fullfile(project_root,'ml_ems'));
startup_ml_ems;
addpath(fullfile(project_root,'ml_ems','continuation'),'-begin');
assert(~bdIsLoaded('EMT_ML'),'Save and close EMT_ML before running.');
cfg=continuation_config(project_root);
cfg.version='grid-ecms-constraint-capture-v1';
cfg.control.log_constraint_replay=true;
cfg.control.reference_balance_soft=reference_balance_soft;
if reference_balance_soft, cfg.version='reference-interface-experimental-v1'; end
cfg.stop_time=30;
folder=create_run_directory(cfg,'constraint_replay_check');
% Archive the exact diagnostic/control sources used by this experiment.
source_files={fullfile('controllers','ems_runtime.m'), ...
 fullfile('controllers','ems_step.m'),fullfile('controllers','common','constraint_residual.m'), ...
 fullfile('controllers','common','project_to_feasible_set.m'), ...
 fullfile('controllers','common','project_qp.m'), ...
 fullfile('controllers','common','engine_load_relation.m'), ...
 fullfile('controllers','common','transmission_relations.m'), ...
 fullfile('controllers','common','action_from_power.m'), ...
 fullfile('continuation','ecms_equivalent_step.m'), ...
 fullfile('continuation','run_continuation_experiment.m'), ...
 fullfile('continuation','run_constraint_replay_check.m'), ...
 fullfile('continuation','test_reference_interface.m')};
hashes=cell(size(source_files));
mkdir(fullfile(folder,'source'));
for j=1:numel(source_files)
    source=fullfile(project_root,'ml_ems',source_files{j});
    hashes{j}=file_sha256(source);
    [~,name,ext]=fileparts(source);
    copyfile(source,fullfile(folder,'source',[name ext]));
end
save(fullfile(folder,'source_manifest.mat'),'source_files','hashes','cfg');
run=run_continuation_experiment(cfg,'stress300',3,cfg.seed);
report=struct('status',run.status,'run_folder',run.folder,'output_folder',folder, ...
    'callbacks',0,'max_term_error',NaN,'max_logged_error',NaN,'verified',false, ...
    'experimental_interface',reference_balance_soft,'retained_violation_callbacks',NaN, ...
    'reference_violation_callbacks',NaN,'state_violation_callbacks',NaN, ...
    'fallback_callbacks',NaN,'preflight_passed',false,'acceptance',run.acceptance);
if strcmp(run.status,'completed')
    assert(isfield(run.runtime,'constraint_replay'),'Replay capture missing.');
    records=run.runtime.constraint_replay; dg=run.runtime.diagnostics;
    assert(numel(records)==size(dg,1)&&~isempty(records),'Capture count mismatch.');
    n=numel(records); term_error=zeros(n,1); logged_error=zeros(n,1);
    rows=zeros(n,18); retained=zeros(n,1); state=zeros(n,1); fallback=zeros(n,1);
    for j=1:n
        r=records{j}; local=run.cfg; local.control.Ts=r.dt;
        local.control.dynamic_torque_offset=r.offset;
        [~,~,detail]=constraint_residual(r.safe,r.x,r.o,r.previous,local);
        assert(r.time==dg(j,1)&&r.decision==dg(j,2),'Callback order mismatch.');
        values=[detail.terms detail.command detail.state r.terms r.command r.state dg(j,3:4)];
        assert(all(isfinite(values)),'Nonfinite residuals cannot pass replay verification.');
        term_error(j)=max(abs(detail.terms-r.terms));
        logged_error(j)=max(abs([detail.command detail.state]-dg(j,3:4)));
        assert(isfinite(detail.projection_command) && ...
            abs(detail.projection_command-r.projection_command)<=1e-6, ...
            'Projection diagnostic replay mismatch.');
        retained(j)=detail.projection_command; state(j)=detail.state; fallback(j)=r.fallback;
        rows(j,:)=[r.time r.decision r.fallback r.dt r.offset detail.terms logged_error(j)];
    end
    report.callbacks=n; report.max_term_error=max(term_error);
    report.max_logged_error=max(logged_error);
    report.verified=report.max_term_error<=1e-6 && report.max_logged_error<=1e-6;
    tol=cfg.control.constraint_tolerance;
    report.retained_violation_callbacks=sum(retained>tol);
    report.reference_violation_callbacks=sum(rows(:,16)>tol);
    report.state_violation_callbacks=sum(state>tol);
    report.fallback_callbacks=sum(fallback~=0);
    report.preflight_passed=report.verified && all(retained<=tol) && ...
        all(state<=tol) && all(fallback==0);
    % This gate covers retained constraints only, not validated vehicle dynamics.
    writetable(table(cellfun(@(r)r.time,records(:)),retained,state,fallback, ...
        'VariableNames',{'time','retained_violation','state_violation','fallback'}), ...
        fullfile(folder,'interface_terms.csv'));
    columns={'time','decision','fallback','dt','offset','ne_lower','ne_upper', ...
        'Te_lower','Te_upper','TA_lower','TA_upper','TB_lower','TB_upper', ...
        'Pb_lower','Pb_upper','torque_balance','rate_max','logged_error'};
    writetable(array2table(rows,'VariableNames',columns),fullfile(folder,'terms.csv'));
end
save(fullfile(folder,'verification.mat'),'report');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot write verification.json');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fprintf('CONSTRAINT_REPLAY_CHECK=%s\n',folder);
disp(report);
assert(report.verified,'EMS:ReplayNotVerified','Replay verification did not pass; inspect saved results.');
end
