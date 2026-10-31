function run_stage2_profile(project,base)
assert(~isfolder(base));mkdir(base);diary(fullfile(base,'profile.log'));
cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
cfg=continuation_config(project);cfg.stop_time=3;cfg.paths.results=fullfile(base,'runs');
mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
cfg.cycle_name='stress300';
profile clear;profile on -history;
run=run_continuation_experiment(cfg,load_cycle('stress300'),7,20260906);
profile off;info=profile('info');save(fullfile(base,'matlab_profile.mat'),'info');
assert(strcmp(run.status,'completed'),run.error);
ft=info.FunctionTable;names={ft.FunctionName}';total=[ft.TotalTime]';calls=[ft.NumCalls]';
self=total;
for k=1:numel(ft)
 if ~isempty(ft(k).Children),self(k)=total(k)-sum([ft(k).Children.TotalTime]);end
end
tableOut=table(names,calls,total,self);tableOut=sortrows(tableOut,'self','descend');
writetable(tableOut,fullfile(base,'function_profile.csv'));
keep=contains(names,{'ems_runtime','ems_sfun','execution_guard_limits','motor_speed_feasibility', ...
 'project_to_feasible_set','project_qp','constraint_residual','engine_torque_guard','interp1','mldivide'});
disp(sortrows(table(names(keep),calls(keep),total(keep),self(keep)),'Var3','descend'));
fprintf('PROFILE_FINISHED %s\n',run.folder);
end
