function folder = run_paired_grid_ecms_full(project_root)
%RUN_PAIRED_GRID_ECMS_FULL Run paired Existing/grid-ECMS suburban and stress cycles.
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
names = controller_registry();
cycles = {'suburban400','stress300'};
runs = cell(numel(cycles),2);
folder = create_run_directory(cfg,'paired_grid_ecms_full');
for k = 1:numel(cycles)
    cycle = load_cycle(cycles{k});
    if isfield(cfg,'reference_RMSE')
        cfg = rmfield(cfg,'reference_RMSE');
    end
    cfg.controller_id = 1;
    cfg.controller_name = names{1};
    baseline = run_continuation_experiment(cfg,cycle,1,cfg.seed);
    assert(strcmp(baseline.status,'completed'),'Existing baseline failed for %s.',cycles{k});
    cfg.controller_id = 3;
    cfg.controller_name = names{3};
    cfg.reference_RMSE = baseline.metrics.RMSE_kmh;
    runs{k,1} = baseline;
    runs{k,2} = run_continuation_experiment(cfg,cycle,3,cfg.seed);
    fprintf('PAIRED_FULL %s Existing=%s gridECMS=%s\n',cycles{k},baseline.status,runs{k,2}.status);
end
save(fullfile(folder,'paired_full.mat'),'runs','cfg','cycles','-v7.3');
fprintf('PAIRED_FULL_SUMMARY=%s\n',folder);
end
