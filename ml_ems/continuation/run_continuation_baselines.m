function run_continuation_baselines(project_root)
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems; addpath(fullfile(project_root,'ml_ems','continuation'),'-begin');
cfg=continuation_config(project_root); cfg.stop_time=Inf;
test_continuation_accounting(project_root); test_power_accounting;
folder=create_run_directory(cfg,'continuation_baselines'); catalog=struct('jobs',struct('cycle',{},'method',{},'seed',{},'label',{},'cfg',{}),'runs',{{}});
cycles={'city200','suburban400','stress300'};
for c=1:3
 local=cfg;
 for method=[1 3 2]
  cycle=load_cycle(cycles{c});
  if method==2
   local.dp_plan=solve_continuation_dp(cycle,local);
   save(fullfile(folder,[cycles{c} '_dp_plan.mat']),'local');
   if ~local.dp_plan.feasible_rollout, fprintf('DP_INFEASIBLE=%s\n',cycles{c}); end
  end
  recovery=fullfile(cfg.paths.results,'city200_m1_s20260906_20260907_211150_00e20b7b','run.mat');
  if c==1&&method==1&&isfile(recovery)
   loaded=load(recovery,'run'); run=loaded.run;
   assert(strcmp(run.status,'completed')&&run.time(end)>=200&&strcmp(run.cfg.version,cfg.version));
   assert(run.cfg.mass_scale==local.mass_scale&&run.cfg.initial_soc_percent==local.initial_soc_percent);
   fprintf('RECOVER_COMPLETED=%s\n',run.folder);
  else
   run=run_continuation_experiment(local,cycle,method,cfg.seed);
  end
  if method==1&&strcmp(run.status,'completed'), local.reference_RMSE=run.metrics.RMSE_kmh; end
  k=numel(catalog.jobs)+1;
  catalog.jobs(k)=struct('cycle',cycles{c},'method',method,'seed',cfg.seed,'label','copy_baseline','cfg',local);
  catalog.runs{end+1}=struct('job_index',k,'folder',run.folder);
  save(fullfile(folder,'catalog.mat'),'catalog','cfg'); export_tables(cfg,catalog,folder);
 end
end
fprintf('BASELINE_SUMMARY=%s\n',folder);
end
