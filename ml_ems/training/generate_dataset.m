function dataset=generate_dataset(cfg)
folder=fullfile(cfg.paths.datasets,['dataset_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]); mkdir(folder);
dataset=struct('version',cfg.version,'folder',folder,'runs',{{}},'cfg',cfg, ...
 'split_rule','Whole trajectories grouped by seed; fixed test cycles excluded; perturbed base-family overlap is explicitly retained.');
for split={'train','validation'}
 if strcmp(split{1},'train'), seeds=cfg.training_seeds; else, seeds=cfg.validation_seeds; end
 for seed=seeds
  bases={'city200','suburban400'}; base=load_cycle(bases{1+mod(seed,2)});
  cycle=perturb_cycle(base,seed,split{1},cfg.dataset_duration);
  method=cfg.dataset_experts(1+mod(seed,numel(cfg.dataset_experts)));
  local=cfg; local.stop_time=cycle.time(end);
  if method==2, local.dp_plan=solve_dp(cycle,local); end
  run=run_experiment(local,cycle,method,seed);
  entry=struct('folder',run.folder,'status',run.status,'split',split{1},'seed',seed,'family',base.name,'expert',method);
  dataset.runs{end+1}=entry;
  save(fullfile(folder,'dataset.mat'),'dataset');
 end
end
save(fullfile(cfg.paths.datasets,'active_dataset.mat'),'dataset');
end
