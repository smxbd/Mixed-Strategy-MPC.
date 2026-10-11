function rebuild_and_check
cfg=experiment_config; build_emt_ml(cfg); cfg.stop_time=30;
for method=[1 4 7]
 run=run_experiment(cfg,'city200',method,1); assert(strcmp(run.status,'completed'),'Closed-loop check failed');
end
finish_baseline_parity; test_core; aggregate_results(cfg);
end
