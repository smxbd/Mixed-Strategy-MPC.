function cfg=continuation_config(project_root)
% Use the verified Stage D runtime configuration, not the generic stub API.
root=fullfile(project_root,'ml_ems'); addpath(root); paths=startup_ml_ems;
training_file = fullfile(project_root, 'ml_ems', 'datasets', ...
    'tped60d12a_aa1c_4f8a_8adf_7dac1f869816', 'training_config.mat');
assert(isfile(training_file), 'training_config.mat not found: %s', training_file);
a=load(training_file,'cfg'); cfg=a.cfg;
cfg.paths=paths; cfg.p=init_baseline_params();
cfg.cycles_dir=fullfile(paths.root,'cycles','generated'); cfg.results_dir=paths.results; cfg.datasets_dir=paths.datasets; cfg.models_dir=paths.models;
cfg.model_dir=fullfile(project_root, 'ml_ems', 'models', 'trained');
policy=jsondecode(fileread(fullfile(root,'config','transformer_runtime_policy.json')));
assert(strcmpi(file_sha256(fullfile(paths.models,'EMT_ML.slx')),policy.model_sha256), ...
 'Model differs from the repaired model used for the completed 200 s comparison.');
cfg.version='copy-continuation-20260907-v3'; cfg.ensemble_size=1;
cfg.control.incremental_balance=true; cfg.control.qp_projection=true;
cfg.control.warmup=true; cfg.control.rate=double(cfg.control.rate);
cfg.stop_time=30; cfg.fast_restart=false; cfg.mass_scale=1;
cfg.initial_soc_percent=60; cfg.seed=20260906;
end
