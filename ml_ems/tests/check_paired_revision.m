function check_paired_revision
cfg=experiment_config; cfg.stop_time=30;
folder=create_run_directory(cfg,'paired_revision'); diary(fullfile(folder,'check.log'));
baseline=run_experiment(cfg,'city200',1,1);
assert(strcmp(baseline.status,'completed'),'Paired baseline failed');
cfg.reference_RMSE=baseline.metrics.RMSE_kmh;
records={baseline};
for method=[3 4 7]
 records{end+1}=run_experiment(cfg,'city200',method,1); %#ok<AGROW>
 save(fullfile(folder,'records.mat'),'records','-v7.3');
end
summary=cellfun(@(r)struct('method',r.cfg.controller_id,'folder',r.folder,'status',r.status, ...
 'metrics',r.metrics,'acceptance',r.acceptance),records,'UniformOutput',false);
fid=fopen(fullfile(folder,'summary.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true)); fclose(fid);
aggregate_results(cfg);
diary off;
end
