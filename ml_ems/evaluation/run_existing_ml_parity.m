function report=run_existing_ml_parity(project_root,reference_folder)
if nargin<1, project_root=[]; end
project_root=resolve_baseline_project(project_root); root=fullfile(project_root,'ml_ems');
old_path=path; clean=onCleanup(@()path(old_path));
addpath(fullfile(root,'config'),fullfile(root,'cycles'),fullfile(root,'evaluation'),'-begin');
folder=tempname(fullfile(root,'results')); mkdir(folder);
report=struct('status','running','folder',folder,'stageD_ready',false);
report.model_sha256=file_sha256(fullfile(root,'models','EMT_ML.slx'));
p=init_baseline_params(); cfg=baseline_validation_config();
% Match the original ACTIVE constants, not the disconnected fg_map lookup.
cycle=struct('name','city200_parity','time',p.Time','v_ref',p.v_cyc', ...
    'road_resistance',.045+zeros(numel(p.Time),1),'grade',zeros(numel(p.Time),1), ...
    'steering_angle',zeros(numel(p.Time),1),'aux_power',interp1(p.Time_ele,p.ele_map,p.Time)');
save(fullfile(folder,'parity_report.mat'),'report','cycle','cfg');
fprintf('EXISTING_PARITY_DIR=%s\n',folder);
old_rng=rng; rngclean=onCleanup(@()rng(old_rng));
try
    rng(cfg.seed,'twister');
    if nargin<2 || isempty(reference_folder)
        [original,report.original_folder]=run_short_simulation(project_root,200,p);
    else
        saved=load(fullfile(reference_folder,'parameter_snapshot.mat'),'params');
        assert(isequaln(p,saved.params),'EMS:ReferenceChanged','Reference parameters differ.');
        saved=load(fullfile(reference_folder,'run_metadata.mat'),'metadata');
        assert(strcmp(saved.metadata.status,'completed')&&saved.metadata.stop_time==200);
        expected=fileread(fullfile(project_root,'EMT.mdl'));
        for callback={'<P Name="PreLoadFcn">parameter;</P>','<P Name="InitFcn">parameter;</P>', ...
                '<P Name="StopFcn">save(&apos;result.mat&apos;);</P>'}
            expected=strrep(expected,callback{1},'');
        end
        assert(strcmp(expected,fileread(fullfile(reference_folder,'EMT.mdl'))),'EMS:ReferenceModelChanged');
        saved=load(fullfile(reference_folder,'short_simulation_output.mat'),'out');
        original=saved.out; report.original_folder=reference_folder;
    end
    rng(cfg.seed,'twister');
    [modified,report.modified_folder,~,report.wiring]=run_existing_ml_simulation(project_root,p,cycle);
    report.signals=compare_baseline_outputs(original,modified,cfg);
    a=modified.parity_original_action; tr=modified.ems_trace;
    ta=a.time(:); tt=tr.time(:); action=normalize_action_log(a); trace=[tr.signals.values];
    assert(isequal(size(ta),size(tt))&&all(abs(ta-tt)<cfg.time_tolerance),'EMS:ActionTimes','Action log times differ.');
    assert(size(trace,2)==62&&all(trace(:,62)==1),'EMS:WrongController','Controller ID is not consistently 1.');
    report.action_max_abs=max(abs(action-trace(:,44:47)),[],'all');
    report.raw_safe_max_abs=max(abs(trace(:,40:43)-trace(:,44:47)),[],'all');
    report.actions_passed=all(isfinite(action),'all')&& ...
        all(isfinite(trace(:,40:47)),'all')&&report.action_max_abs==0&&report.raw_safe_max_abs==0;
    report.status='failed';
    if all(report.signals.Passed)&&report.actions_passed
        report.status='passed'; report.stageD_ready=true;
    end
    report.warnings='Inherited wiring/derivative/quantization warnings retained; parity is not physical safety certification.';
    writetable(report.signals,fullfile(folder,'signal_parity.csv')); disp(report.signals);
catch exception
    report.status='error'; report.reason=getReport(exception,'extended','hyperlinks','off');
    save(fullfile(folder,'parity_report.mat'),'report','cycle','cfg'); rethrow(exception)
end
save(fullfile(folder,'parity_report.mat'),'report','cycle','cfg');
fprintf('EXISTING_PARITY_STATUS=%s; ACTION_ERROR=%g\n',report.status,report.action_max_abs);
end
