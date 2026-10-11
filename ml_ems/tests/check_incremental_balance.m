function check_incremental_balance
cfg=experiment_config; cfg.stop_time=30;
cfg.version='ems-r2024b-v4-incremental-experimental';
cfg.control.incremental_balance=true;
cfg.reference_RMSE=.6163024864425025;
run=run_experiment(cfg,'city200',7,1);
assert(strcmp(run.status,'completed'),'Incremental balance simulation failed');
disp(run.metrics); disp(run.acceptance);
end
