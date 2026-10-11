function run_residual_main
test_core; test_result_accounting; test_power_accounting;
cfg=experiment_config;
cfg.version='ems-r2024b-v7-residual-power-accounting';
cfg.model_dir=fullfile(cfg.paths.results,'residual_training_20260906_143055_b35599be','models');
assert(isfile(fullfile(cfg.model_dir,'transformer_3.mat')),'Residual ensemble missing');
cfg.source_snapshot=snapshot_source(cfg);
cfg.model_sha256=file_sha256(fullfile(cfg.paths.models,'EMT_ML.slx'));
short=cfg; short.stop_time=30; short.reference_RMSE=.6163024864425025;
check=run_experiment(short,'city200',7,1);
assert(strcmp(check.status,'completed'),'Preflight simulation failed');
assert(isfield(check.metrics,'max_safety_callback_s')&&isfield(check.metrics,'max_decision_callback_s'),'Detailed timing missing');
% Full comparisons retain unsuccessful acceptance; completion is not a safety claim.
batch_experiments(cfg,'main'); aggregate_results(cfg);
end
