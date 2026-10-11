function check_qp_revision
test_core; test_result_accounting;
cfg=experiment_config; cfg.stop_time=30; cfg.reference_RMSE=.6163024864425025;
run=run_experiment(cfg,'city200',7,1);
assert(strcmp(run.status,'completed'),'QP revision simulation failed');
disp(run.metrics); disp(run.runtime); disp(run.acceptance);
end
