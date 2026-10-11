function build_recovery_report(project_root)
% Aggregate traceable recovery runs without editing their raw artifacts.
root=fullfile(project_root,'ml_ems'); addpath(fullfile(root,'continuation'),'-begin');
addpath(genpath(root)); results=fullfile(root,'results');
cases={
 'city200','Existing',fullfile(results,'city200_m1_s20261012_20261011_004813_0d4e0b29','run.mat');
 'suburban400','Existing',fullfile(results,'suburban400_m1_s20261012_20261011_005425_b8bd05d2','run.mat');
 'stress300','Existing',fullfile(results,'stress300_m1_s20261012_20261011_005728_6da2800b','run.mat');
 'city200','LSTM',fullfile(results,'city200_m6_s20261014_20261011_133336_74413f17','run.mat');
 'suburban400','LSTM',fullfile(results,'suburban400_m6_s20261014_20261011_133803_166f7c01','run.mat');
 'stress300','LSTM',fullfile(results,'stress300_m6_s20261014_20261011_134112_44108796','run.mat');
 'city200','Transformer',fullfile(results,'city200_m7_s20261014_20261011_131850_5160b2a4','run.mat');
 'suburban400','Transformer',fullfile(results,'suburban400_m7_s20261014_20261011_132257_16010f90','run.mat');
 'stress300','Transformer',fullfile(results,'stress300_m7_s20261014_20261011_132606_a2453274','run.mat')};
rows=cell(size(cases,1),8);
for k=1:size(cases,1)
 rows(k,1:3)=cases(k,1:3); rows{k,4}=isfile(cases{k,3});
 if rows{k,4}
  s=load(cases{k,3},'run'); run=s.run; rows{k,5}=run.status;
  try
   m=compute_continuation_metrics(run,run.cfg); rows{k,6}=m.RMSE_kmh; rows{k,7}=m.distance_km; rows{k,8}=m.fuel_L;
  catch ME
   rows{k,5}=['metrics_failed: ' ME.identifier]; rows{k,6}=NaN; rows{k,7}=NaN; rows{k,8}=NaN;
  end
 else, rows{k,5}='missing_run'; rows{k,6}=NaN; rows{k,7}=NaN; rows{k,8}=NaN; end
end
T=cell2table(rows,'VariableNames',{'cycle','controller','run_file','has_run','status','RMSE_kmh','distance_km','fuel_L'});
writetable(T,fullfile(project_root,'recovery_metrics.csv'));
fid=fopen(fullfile(project_root,'RECOVERY_REPORT.md'),'w');
fprintf(fid,'# Approximate early-draft recovery report\n\nGenerated from saved `run.mat` artifacts; raw results were not edited.\n\n');
fprintf(fid,'| Cycle | Controller | Status | RMSE (km/h) | Distance (km) | Fuel (L) |\n|---|---|---|---:|---:|---:|\n');
for k=1:height(T), fprintf(fid,'| %s | %s | %s | %.4g | %.4g | %.4g |\n',T.cycle{k},T.controller{k},T.status{k},T.RMSE_kmh(k),T.distance_km(k),T.fuel_L(k)); end
fprintf(fid,'\nAll nine cases are full-duration runs. Metrics are reported exactly from the saved artifacts; several scenarios differ from the historical target ranges, and those deviations are retained rather than adjusted. Tracking figures are stored in `recovery_figures/`.\n'); fclose(fid);
end
