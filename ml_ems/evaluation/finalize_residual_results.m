function finalize_residual_results
cfg=experiment_config; cfg.version='ems-r2024b-v7-residual-power-accounting';
cfg.model_dir=fullfile(cfg.paths.results,'residual_training_20260906_143055_b35599be','models');
cfg.prediction_validation_dir=fullfile(cfg.paths.results,'prediction_validation_20260906_143127_e9cf542f');
summary=aggregate_results(cfg);
plot_training_results(cfg);
T=readtable(fullfile(summary.main,'results.csv'),'TextType','string');
timingNames={'initialization_s','max_decision_callback_s','max_safety_callback_s','max_full_callback_s','real_time_factor'};
timing=T(:,{'Cycle','Method','MethodID','Status','Accepted'});
for j=1:numel(timingNames), timing.(timingNames{j})=NaN(height(T),1); end
for k=1:height(T)
 if T.Status(k)~="completed", continue; end
 saved=load(fullfile(T.RunFolder(k),'run.mat'),'run');
 for j=1:numel(timingNames)
  if isfield(saved.run.metrics,timingNames{j}), timing.(timingNames{j})(k)=saved.run.metrics.(timingNames{j}); end
 end
 destination=fullfile(summary.main,'working_points',sprintf('%s_m%d_s%d',saved.run.cycle.name,saved.run.cfg.controller_id,saved.run.cfg.seed));
 plot_working_points(saved.run.cfg,saved.run,destination);
end
writetable(timing,fullfile(summary.main,'timing_details.csv'));
writetable(timing,fullfile(summary.main,'timing_details.xlsx'));
save(fullfile(summary.main,'timing_details.mat'),'timing');
end
