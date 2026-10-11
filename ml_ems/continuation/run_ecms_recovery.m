function folder = run_ecms_recovery(project_root)
%RUN_ECMS_RECOVERY Re-run only the failed full-cycle ECMS baselines.
if nargin < 1
    project_root = fileparts(fileparts(mfilename('fullpath')));
    project_root = fileparts(project_root);
end
root = fullfile(project_root,'ml_ems');
addpath(root,'-begin');
addpath(fullfile(root,'continuation'),'-begin');
startup_ml_ems;
cfg = continuation_config(project_root);
cfg.stop_time = Inf;
cfg.controller_id = 3;
names = controller_registry();
cfg.controller_name = names{3};
folder = create_run_directory(cfg,'ecms_recovery');
cycles = {'city200','suburban400','stress300'};
runs = cell(size(cycles));
for k = 1:numel(cycles)
    cycle = load_cycle(cycles{k});
    runs{k} = run_continuation_experiment(cfg,cycle,3,cfg.seed);
    fprintf('ECMS_RECOVERY %s %s\n',cycles{k},runs{k}.status);
end
save(fullfile(folder,'recovery.mat'),'runs','cfg','cycles','-v7.3');
fprintf('ECMS_RECOVERY_SUMMARY=%s\n',folder);
end
