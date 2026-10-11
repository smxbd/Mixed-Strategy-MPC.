function complete_residual_suite
% Execute after the active main batch has exited; preserve all previous runs.
cfg=experiment_config; cfg.version='ems-r2024b-v7-residual-power-accounting';
cfg.model_dir=fullfile(cfg.paths.results,'residual_training_20260906_143055_b35599be','models');
controller=fullfile(cfg.paths.root,'controllers','ems_step.m'); source=fileread(controller);
old='p=predict(a.net,z); p=p.*a.sigmaY+a.muY;';
replacement='p=predict(a.net,z); p=double(p.*a.sigmaY+a.muY);';
if contains(source,old)
 backup=create_run_directory(cfg,'mlp_precision_patch'); copyfile(controller,fullfile(backup,'ems_step_before.m'));
 fid=fopen(controller,'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',strrep(source,old,replacement)); fclose(fid);
elseif ~contains(source,replacement), error('Unexpected MLP source; no patch applied.'); end
clear ems_step
cfg.implementation_patch='MLP output cast to double before action mapping; all non-MLP branches unchanged.';
test_core; test_result_accounting; test_power_accounting;
testcfg=cfg; testcfg.controller_id=4; nets=load_trained_models(testcfg); warmup_controller(testcfg,nets);
cfg.source_snapshot=snapshot_source(cfg); cfg.model_sha256=file_sha256(fullfile(cfg.paths.models,'EMT_ML.slx'));
folders=dir(fullfile(cfg.paths.results,'main_shard*')); [~,order]=sort([folders.datenum],'descend'); catalog=[];
for n=order
 file=fullfile(folders(n).folder,folders(n).name,'catalog.mat'); if ~isfile(file), continue; end
 saved=load(file,'catalog');
 if ~isempty(saved.catalog.jobs)&&strcmp(saved.catalog.jobs(1).cfg.version,cfg.version), catalog=saved.catalog; break; end
end
assert(~isempty(catalog),'Matching main catalog missing.');
% Only the formerly unusable single-precision MLP path changes numerically.
% Each actual run retains its original cfg/source snapshot; no result is relabeled.
done=false(1,numel(catalog.jobs)); paired=containers.Map('KeyType','char','ValueType','double');
for n=1:numel(catalog.runs)
 item=catalog.runs{n}; file=fullfile(item.folder,'run.mat'); if ~isfile(file), continue; end
 saved=load(file,'run'); r=saved.run;
 if strcmp(r.status,'completed')
  done(item.job_index)=true;
  if r.cfg.controller_id==1, paired(r.cycle.name)=r.metrics.RMSE_kmh; end
 end
end
for n=find(~done)
 j=catalog.jobs(n); local=cfg; cycle=load_cycle(j.cycle);
 local.experiment_group='main'; local.experiment_label=j.label;
 if isKey(paired,cycle.name), local.reference_RMSE=paired(cycle.name); end
 if j.method==2, local.dp_plan=solve_dp(cycle,local); end
 r=run_experiment(local,cycle,j.method,j.seed);
 if j.method==1&&strcmp(r.status,'completed'), paired(cycle.name)=r.metrics.RMSE_kmh; end
 catalog.runs{end+1}=struct('job_index',n,'folder',r.folder,'status',r.status,'label',j.label);
 save(fullfile(catalog.folder,'catalog.mat'),'catalog'); export_tables(cfg,catalog,catalog.folder);
end
finalize_residual_results;
for kind={'ablation','robustness','generalization'}
 run_followup(cfg,kind{1},paired);
 aggregate_results(cfg);
end
finalize_residual_results;
end

function run_followup(cfg,kind,paired)
folder=create_run_directory(cfg,[kind '_shard1']); jobs=build_experiment_matrix(cfg,kind);
catalog=struct('kind',kind,'folder',folder,'jobs',jobs,'runs',{{}},'shard',1,'shards',1);
save(fullfile(folder,'catalog.mat'),'catalog');
for n=1:numel(jobs)
 j=jobs(n); local=j.cfg; cycle=load_cycle(j.cycle);
 local.experiment_group=kind; local.experiment_label=j.label;
 if isKey(paired,cycle.name), local.reference_RMSE=paired(cycle.name); end
 if j.method==2, local.dp_plan=solve_dp(cycle,local); end
 r=run_experiment(local,cycle,j.method,j.seed);
 if j.method==1&&strcmp(r.status,'completed'), paired(cycle.name)=r.metrics.RMSE_kmh; end
 catalog.runs{end+1}=struct('job_index',n,'folder',r.folder,'status',r.status,'label',j.label);
 save(fullfile(folder,'catalog.mat'),'catalog'); export_tables(cfg,catalog,folder);
end
end
