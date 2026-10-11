function run_full_suite
cfg=experiment_config;
for group={'main','ablation','robustness','generalization'}, batch_experiments(cfg,group{1}); end
end
