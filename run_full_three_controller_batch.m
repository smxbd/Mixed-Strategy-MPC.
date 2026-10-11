root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'ml_ems')); startup_ml_ems; cfg=continuation_config(root); cfg.stop_time=inf; cfg.control.warmup=true; methods=[1 7 6]; cycles={'city200','suburban400','stress300'}; summary={};
for ic=1:numel(cycles)
 c=load_cycle(cycles{ic},cfg.cycles_dir); cfg.stop_time=c.time(end);
 for im=1:numel(methods)
  m=methods(im); fprintf('START %s method %d\n',cycles{ic},m); r=run_continuation_experiment(cfg,c,m,cfg.seed); summary{end+1}=r; %#ok<SAGROW>
 end
end
save(fullfile(root,'full_three_controller_batch.mat'),'summary','-v7.3');
