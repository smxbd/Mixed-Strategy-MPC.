function test_result_accounting
% Regression coverage: held-step infeasibility, version exclusion, failed retry.
cfg=experiment_config; cfg.reference_RMSE=1;
folder=create_run_directory(cfg,'test_accounting');
m=struct('constraint_violations',0,'safety_infeasible_samples',1, ...
 'physical_violation_samples',0,'max_computation_s',.01,'RMSE_kmh',1,'fuel_L_100km',100);
run=struct('status','completed','metrics',m,'cfg',cfg,'folder',folder);
a=assess_run(run,cfg); assert(~a.hard_commands_pass&&~a.accepted);
run.metrics.safety_infeasible_samples=0;
a=assess_run(run,cfg); assert(a.accepted);
jobs=build_experiment_matrix(cfg,'main'); jobs=jobs(1);
catalog=struct('jobs',jobs,'runs',{{struct('job_index',1,'folder',folder)}});
run.cfg.version='older-test-version'; save(fullfile(folder,'run.mat'),'run');
T=export_tables(cfg,catalog,folder); assert(strcmp(T.Status{1},'not_run')&&isnan(T.fuel_L_100km));
run.cfg=cfg; save(fullfile(folder,'run.mat'),'run');
T=export_tables(cfg,catalog,folder); assert(T.fuel_L_100km==100&&T.Accepted);
retry=fullfile(folder,'retry'); mkdir(retry); run.status='failed'; run.metrics=struct; run.folder=retry;
save(fullfile(retry,'run.mat'),'run');
catalog.runs{end+1}=struct('job_index',1,'folder',retry);
T=export_tables(cfg,catalog,folder);
assert(strcmp(T.Status{1},'failed')&&isnan(T.fuel_L_100km)&&~T.Accepted);
fprintf('Result accounting tests passed. Synthetic fixtures only: %s\n',folder);
end
