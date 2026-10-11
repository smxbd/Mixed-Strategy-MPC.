function report = run_stageC_checks(project_root)
if nargin < 1, project_root = []; end
project_root = resolve_baseline_project(project_root);
ems_root = fullfile(project_root,'ml_ems');
addpath(fullfile(ems_root,'evaluation'),fullfile(ems_root,'config'), ...
    fullfile(ems_root,'cycles'),fullfile(ems_root,'tests'), ...
    fullfile(ems_root,'controllers','ecms'),'-begin');
report = struct('timestamp',datestr(now,30));
report.test_stageB_C = test_stageB_C();
assert(report.test_stageB_C,'EMS:InterfaceTestFailed','Interface tests failed.');
% One simulation only. Propagate the full error instead of hiding it in a struct.
report.baseline = reproduce_baseline(project_root,30);
report.short_simulation = struct('status','completed', ...
    'run_dir',report.baseline.run_dir,'stop_time',30);
report.stageD_ready = false;
report.remaining = 'Full-cycle simulation and baseline parity have not been verified.';
save(fullfile(report.baseline.run_dir,'stageC_checks.mat'),'report');
end
