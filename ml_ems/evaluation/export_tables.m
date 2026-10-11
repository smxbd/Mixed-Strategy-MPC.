function T=export_tables(cfg,catalog,folder)
rows={}; metricNames={'fuel_L_100km','equivalent_fuel_L_100km','delta_SOC_percent','RMSE_kmh','distance_error_percent', ...
 'mean_computation_s','max_computation_s','constraint_violations','physical_violation_samples','fallback_count'};
names=controller_registry;
for k=1:numel(catalog.jobs)
 j=catalog.jobs(k); cycle=load_cycle(j.cycle);
 row=struct('Cycle',cycle.name,'Method',names{j.method},'MethodID',j.method,'Seed',j.seed,'Label',j.label,'Status','not_run','RunFolder','', ...
  'Version',cfg.version,'Accepted',false,'HardCommandsPass',false,'PhysicalLimitsPass',false,'OnlineBudgetPass',false,'TrackingComparable',false);
 for q=1:numel(metricNames), row.(metricNames{q})=NaN; end
 for r=1:numel(catalog.runs)
  item=catalog.runs{r}; if item.job_index~=k, continue; end
  a=load(fullfile(item.folder,'run.mat'),'run'); run=a.run;
  if ~strcmp(run.cfg.version,cfg.version), continue; end
  row.Status=run.status; row.RunFolder=run.folder;
  % A later failed retry must not inherit metrics from an earlier success.
  for q=1:numel(metricNames), row.(metricNames{q})=NaN; end
  acceptance=assess_run(run,run.cfg);
  row.Accepted=acceptance.accepted; row.HardCommandsPass=acceptance.hard_commands_pass;
  row.PhysicalLimitsPass=acceptance.physical_limits_pass; row.OnlineBudgetPass=acceptance.online_budget_pass;
  row.TrackingComparable=acceptance.tracking_comparable;
  if strcmp(run.status,'completed')
   for q=1:numel(metricNames), if isfield(run.metrics,metricNames{q}), row.(metricNames{q})=run.metrics.(metricNames{q}); end, end
   if j.method==1, row.mean_computation_s=NaN; row.max_computation_s=NaN; end
  end
 end
 rows{k}=row; %#ok<AGROW>
end
T=struct2table([rows{:}],'AsArray',true); writetable(T,fullfile(folder,'results.csv')); writetable(T,fullfile(folder,'results.xlsx'));
save(fullfile(folder,'results_table.mat'),'T');
fid=fopen(fullfile(folder,'results.tex'),'w'); fprintf(fid,'\\begin{tabular}{llrrrrrr}\n\\hline\nCycle & Method & Fuel & Eq. fuel & SOC & RMSE & Time & Violations \\\\\n');
for k=1:height(T)
 fprintf(fid,'%s & %s & %.3f & %.3f & %.3f & %.3f & %.5f & %.0f \\\\\n', ...
  strrep(T.Cycle{k},'_','\_'),strrep(T.Method{k},'_','\_'),T.fuel_L_100km(k),T.equivalent_fuel_L_100km(k),T.delta_SOC_percent(k),T.RMSE_kmh(k),T.mean_computation_s(k),T.constraint_violations(k));
end
fprintf(fid,'\\hline\n\\end{tabular}\n'); fclose(fid);
end
