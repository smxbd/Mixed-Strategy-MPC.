function run = run_grid_ecms_preflight(project_root)
%RUN_GRID_ECMS_PREFLIGHT Validate the restored finite-grid ECMS branch.
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
cfg.controller_id = 3;
names = controller_registry();
cfg.controller_name = names{3};
run = run_continuation_experiment(cfg,'city200',3,cfg.seed);
fprintf('GRID_ECMS_PREFLIGHT=%s\n',run.status);
end
