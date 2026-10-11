function report = diagnose_grid_ecms_runs(project_root)
%DIAGNOSE_GRID_ECMS_RUNS Summarize existing paired grid-ECMS failures.
if nargin < 1
    project_root = fileparts(fileparts(mfilename('fullpath')));
    project_root = fileparts(project_root);
end
root = fullfile(project_root,'ml_ems','results');
folders = { ...
 'suburban400_m3_s20260906_20260908_152859_5c5fdbe7', ...
 'stress300_m3_s20260906_20260908_153549_3a4ae2be'};
report = struct('folder',{},'status',{},'peak_speed_error',{}, ...
 'first_infeasible_time',{},'last_infeasible_time',{}, ...
 'infeasible_count',{},'fallback_count',{},'max_command_residual',{}, ...
 'max_state_residual',{},'current_violation_samples',{}, ...
 'engine_violation_samples',{},'motor_violation_samples',{});
for k = 1:numel(folders)
    d = fullfile(root,folders{k});
    a = load(fullfile(d,'run.mat'),'run'); run = a.run;
    dg = run.runtime.diagnostics;
    dec = dg(:,2)>0;
    bad = dec & dg(:,3)>run.cfg.control.constraint_tolerance;
    r = struct(); r.folder=folders{k}; r.status=run.status;
    obs=run.trace(:,20:39); e=obs(:,1)-obs(:,2);
    r.peak_speed_error=max(abs(e));
    r.first_infeasible_time=NaN; r.last_infeasible_time=NaN;
    if any(bad), r.first_infeasible_time=dg(find(bad,1),1); r.last_infeasible_time=dg(find(bad,1,'last'),1); end
    r.infeasible_count=sum(bad); r.fallback_count=run.metrics.safety_fallback_samples;
    r.max_command_residual=max(dg(:,3)); r.max_state_residual=max(dg(:,4));
    m=run.metrics; r.current_violation_samples=m.current_violation_samples;
    r.engine_violation_samples=m.engine_violation_samples; r.motor_violation_samples=m.motor_violation_samples;
    report(end+1)=r; %#ok<AGROW>
end
out = fullfile(root,['grid_ecms_diagnostic_' datestr(now,'yyyymmdd_HHMMSS')]); mkdir(out);
save(fullfile(out,'diagnostic.mat'),'report','-v7.3');
fid=fopen(fullfile(out,'diagnostic.txt'),'w'); fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true)); fclose(fid);
fprintf('GRID_ECMS_DIAGNOSTIC=%s\n',out);
end
