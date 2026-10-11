function summary=aggregate_results(cfg)
folder=create_run_directory(cfg,'paper_tables'); groups={'main','ablation','robustness','generalization'};
summary=struct('folder',folder);
for g=1:numel(groups)
 catalog=struct('kind',groups{g},'jobs',build_experiment_matrix(cfg,groups{g}),'runs',{{}});
 dirs=dir(fullfile(cfg.paths.results,[groups{g} '_shard*']));
 for k=1:numel(dirs)
  p=fullfile(dirs(k).folder,dirs(k).name,'catalog.mat'); if ~isfile(p), continue; end
  d=load(p,'catalog');
  if isempty(d.catalog.jobs)||~strcmp(d.catalog.jobs(1).cfg.version,cfg.version), continue; end
  catalog.runs=[catalog.runs d.catalog.runs];
 end
 sub=fullfile(folder,groups{g}); mkdir(sub); T=export_tables(cfg,catalog,sub); summary.(groups{g})=sub;
 if strcmp(groups{g},'robustness')
  C=unique(T.Cycle); R={}; n=0;
  for c=1:numel(C), for method=5:8
   x=T(strcmp(T.Cycle,C{c})&T.MethodID==method,:); ok=strcmp(x.Status,'completed');
   n=n+1; R{n}=struct('Cycle',C{c},'Method',x.Method{1},'Completed',sum(ok),'Planned',height(x), ...
    'FuelMean',mean(x.fuel_L_100km(ok)),'FuelStd',std(x.fuel_L_100km(ok)), ...
    'EquivalentFuelMean',mean(x.equivalent_fuel_L_100km(ok)),'EquivalentFuelStd',std(x.equivalent_fuel_L_100km(ok)), ...
    'RMSEMean',mean(x.RMSE_kmh(ok)),'RMSEStd',std(x.RMSE_kmh(ok)),'ConstraintViolations',sum(x.constraint_violations(ok)));
   if sum(ok)<2, R{n}.FuelStd=NaN; R{n}.EquivalentFuelStd=NaN; R{n}.RMSEStd=NaN; end
   if ~any(ok), R{n}.ConstraintViolations=NaN; end
  end, end
  robustness=struct2table([R{:}]); writetable(robustness,fullfile(sub,'robustness_summary.csv')); writetable(robustness,fullfile(sub,'robustness_summary.xlsx')); save(fullfile(sub,'robustness_summary.mat'),'robustness');
 end
 if strcmp(groups{g},'main')
  for c={'city200','suburban400','stress300'}
   rows=T(strcmp(T.Cycle,c{1})&strcmp(T.Status,'completed'),:);
   if ~isempty(rows), cf=fullfile(sub,c{1}); mkdir(cf); plot_comparison(cfg,rows.RunFolder,cf); end
  end
 end
end
save(fullfile(folder,'summary.mat'),'summary');
end
