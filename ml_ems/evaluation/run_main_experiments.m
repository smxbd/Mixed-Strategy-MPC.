function run_main_experiments
project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
cfg=continuation_config(project_root); cfg.cycles_dir=fullfile(cfg.paths.root,'cycles','generated'); cfg.results_dir=cfg.paths.results;
cfg.source_snapshot=snapshot_source(cfg);
cfg.model_sha256=file_sha256(fullfile(cfg.paths.models,'EMT_ML.slx'));
batch_experiments(cfg,'main'); aggregate_results(cfg);
end
