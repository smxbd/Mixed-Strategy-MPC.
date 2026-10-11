function run_phase_e
cfg=experiment_config; cfg.stop_time=30; folder=create_run_directory(cfg,'phase_e'); diary(fullfile(folder,'phase_e.log'));
finish_baseline_parity;
records=cell(1,7);
for method=2:8
 local=cfg; if method==2, local.dp_plan=solve_dp(build_city200,local); end
 run=run_experiment(local,'city200',method,1);
 records{method-1}=struct('id',method,'folder',run.folder,'status',run.status,'metrics',run.metrics);
 save(fullfile(folder,'short_controller_checks.mat'),'records');
end
fid=fopen(fullfile(folder,'short_controller_checks.json'),'w'); fprintf(fid,'%s',jsonencode(records,'PrettyPrint',true)); fclose(fid);
diary off;
end
