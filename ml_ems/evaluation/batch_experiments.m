function catalog=batch_experiments(cfg,kind)
jobs=build_experiment_matrix(cfg,kind); catalog=struct('kind',kind,'jobs',jobs,'runs',struct([]));
for k=1:numel(jobs)
 local=jobs(k).cfg; local.seed=jobs(k).seed; local.controller_id=jobs(k).method;
 if isstruct(jobs(k).cycle), c=jobs(k).cycle; else, c=load_cycle(jobs(k).cycle,local.cycles_dir); end
 try
  r=run_continuation_experiment(local,c,jobs(k).method,jobs(k).seed);
 catch ME
  r=struct('status','failed','folder','','cycle',c,'cfg',local,'metrics',struct,'error',getReport(ME,'extended','hyperlinks','off'), ...
   'acceptance',struct('accepted',false,'note','Batch isolated failure'));
 end
 r.label=jobs(k).label; r.job_index=k;
 if isempty(catalog.runs), catalog.runs=r; else, catalog.runs(end+1)=r; end
end
folder=create_run_directory(cfg,[char(kind) '_shard']); save(fullfile(folder,'catalog.mat'),'catalog','-v7.3');
end
