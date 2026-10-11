function check_revised_constraints
cfg=experiment_config; cfg.stop_time=30; folder=create_run_directory(cfg,'constraint_revision'); diary(fullfile(folder,'check.log'));
migrate_controller_selector(cfg);
test_core;
records={};
for method=[3 4 7]
 run=run_experiment(cfg,'city200',method,1);
 records{end+1}=struct('method',method,'status',run.status,'folder',run.folder,'metrics',run.metrics);
 save(fullfile(folder,'records.mat'),'records');
end
fid=fopen(fullfile(folder,'records.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(records,'PrettyPrint',true)); fclose(fid);
diary off;
end
