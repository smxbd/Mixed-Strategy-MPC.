function folder = run_paired_grid_ecms_preflight(project_root)
%RUN_PAIRED_GRID_ECMS_PREFLIGHT Compare Existing and grid ECMS identically.
if nargin < 1
    project_root = fileparts(fileparts(mfilename('fullpath')));
    project_root = fileparts(project_root);
end
root = fullfile(project_root,'ml_ems');
addpath(root,'-begin');
addpath(fullfile(root,'continuation'),'-begin');
startup_ml_ems;
cfg = continuation_config(project_root);
cfg.stop_time = 30;
cycle = load_cycle('city200');
names = controller_registry();

cfg.controller_id = 1;
cfg.controller_name = names{1};
existing = run_continuation_experiment(cfg,cycle,1,cfg.seed);
assert(strcmp(existing.status,'completed'),'Existing paired baseline did not complete.');

cfg.controller_id = 3;
cfg.controller_name = names{3};
cfg.reference_RMSE = existing.metrics.RMSE_kmh;
grid_ecms = run_continuation_experiment(cfg,cycle,3,cfg.seed);

folder = create_run_directory(cfg,'paired_grid_ecms_preflight');
save(fullfile(folder,'paired.mat'),'existing','grid_ecms','cfg','-v7.3');
fprintf('PAIRED_EXISTING=%s\n',existing.folder);
fprintf('PAIRED_GRID_ECMS=%s\n',grid_ecms.folder);
fprintf('PAIRED_SUMMARY=%s\n',folder);
end
