function check_timing_revision
test_core;
test_result_accounting;
cfg=experiment_config; cfg.stop_time=30;
cfg.reference_RMSE=.6163024864425025; % Paired immutable-plant city200 30 s baseline.
run=run_experiment(cfg,'city200',7,1);
assert(strcmp(run.status,'completed'),'Timing revision simulation failed');
disp(run.acceptance);
end
