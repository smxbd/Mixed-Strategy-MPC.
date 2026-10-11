function resume_residual_main
% Call only after the previous batch process has ended.
current=experiment_config; version='ems-r2024b-v7-residual-power-accounting';
folders=dir(fullfile(current.paths.results,'main_shard*')); [~,order]=sort([folders.datenum],'descend');
catalog=[];
for k=order
 file=fullfile(folders(k).folder,folders(k).name,'catalog.mat');
 if ~isfile(file), continue; end
 saved=load(file,'catalog');
 if ~isempty(saved.catalog.jobs)&&strcmp(saved.catalog.jobs(1).cfg.version,version), catalog=saved.catalog; break; end
end
assert(~isempty(catalog),'No matching batch to resume; use run_residual_main for a new batch.');
cfg=catalog.jobs(1).cfg;
frozen=load(fullfile(cfg.source_snapshot,'manifest.mat'),'manifest');
for k=1:numel(frozen.manifest)
 item=frozen.manifest(k); name=item.file;
 if startsWith(name,['controllers' filesep])||startsWith(name,['config' filesep])
  source=fullfile(cfg.paths.root,name);
 elseif startsWith(name,['trained_weights' filesep])
  [~,base,ext]=fileparts(name); source=fullfile(cfg.model_dir,[base ext]);
 elseif strcmp(name,'EMT_ML.slx'), source=fullfile(cfg.paths.models,name);
 else, continue;
 end
 assert(isfile(source)&&strcmpi(file_sha256(source),item.sha256),'Source/weight mismatch: %s. Start a new version instead.',name);
end
completed=false(1,numel(catalog.jobs)); paired=containers.Map('KeyType','char','ValueType','double');
for k=1:numel(catalog.runs)
 item=catalog.runs{k}; file=fullfile(item.folder,'run.mat'); if ~isfile(file), continue; end
 saved=load(file,'run'); r=saved.run;
 if ~strcmp(r.status,'completed')||~strcmp(r.cfg.version,version), continue; end
 completed(item.job_index)=true;
 if r.cfg.controller_id==1, paired(r.cycle.name)=r.metrics.RMSE_kmh; end
end
fprintf('Resuming %s: %d/%d completed.\n',catalog.folder,sum(completed),numel(completed));
for k=find(~completed)
 j=catalog.jobs(k); local=j.cfg; cycle=load_cycle(j.cycle);
 local.experiment_group='main'; local.experiment_label=j.label;
 if isKey(paired,cycle.name), local.reference_RMSE=paired(cycle.name); end
 if j.method==2, local.dp_plan=solve_dp(cycle,local); end
 r=run_experiment(local,cycle,j.method,j.seed);
 if j.method==1&&strcmp(r.status,'completed'), paired(cycle.name)=r.metrics.RMSE_kmh; end
 catalog.runs{end+1}=struct('job_index',k,'folder',r.folder,'status',r.status,'label',j.label);
 save(fullfile(catalog.folder,'catalog.mat'),'catalog'); export_tables(cfg,catalog,catalog.folder);
end
aggregate_results(cfg);
end
