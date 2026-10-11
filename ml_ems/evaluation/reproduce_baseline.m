function report = reproduce_baseline(project_root,stop_time)
% Execute an actual smoke run; this is not a baseline parity acceptance test.
if nargin < 1, project_root = []; end
if nargin < 2, stop_time = 30; end
project_root = resolve_baseline_project(project_root);
[~,run_dir] = run_short_simulation(project_root,stop_time);
report = struct('status','short_simulation_completed', ...
    'model',fullfile(project_root,'EMT.mdl'),'run_dir',run_dir, ...
    'stop_time',stop_time,'parity_status','not_run', ...
    'metrics_status','not_computed','timestamp',datestr(now,30));
save(fullfile(run_dir,'baseline_report.mat'),'report');
end
