function run_three_controller_figures
project=fileparts(fileparts(mfilename('fullpath')));
root=fullfile(project,'ml_ems'); addpath(genpath(root));
out=fullfile(project,'figure_outputs','three_controller_20261012','data');
if ~isfolder(out), mkdir(out); end
cycles={'city200','suburban400','stress300'};
names={'Existing','LSTM','Transformer'}; methods=[1 6 7];
cfg=experiment_config(root);
for ci=1:numel(cycles)
 for mi=1:numel(methods)
  dest=fullfile(out,sprintf('%s_%s.mat',cycles{ci},names{mi}));
  if isfile(dest), fprintf('ALREADY_EXPORTED %s\n',dest); continue; end
  cfg.stop_time=Inf;
  fprintf('START %s %s\n',cycles{ci},names{mi});
  run=run_experiment(cfg,cycles{ci},methods(mi),1);
  assert(strcmp(run.status,'completed'),'EMS:IncompleteFigureRun','%s',run.error);
  % Keep all logged trace and physical samples, configuration and metrics.
  % Exclude duplicate Simulink output containers from the plotting export.
  save(dest,'run','-v7.3');
  fprintf('EXPORTED %s RMSE=%.4f fuel=%.4f deltaSOC=%.4f\n',dest, ...
   run.metrics.RMSE_kmh,run.metrics.fuel_L,run.metrics.delta_SOC_percent);
 end
end
fprintf('THREE_CONTROLLER_BATCH_COMPLETE\n');
end
