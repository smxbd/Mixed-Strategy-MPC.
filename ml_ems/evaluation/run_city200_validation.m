function report = run_city200_validation(project_root)
% Parameter-refactor parity only: the EMT plant and EMS are unchanged.
if nargin < 1, project_root = []; end
project_root = resolve_baseline_project(project_root);
root = fullfile(project_root,'ml_ems');
old_path = path; path_cleanup = onCleanup(@()path(old_path));
addpath(fullfile(root,'evaluation'),fullfile(root,'config'), ...
    fullfile(root,'cycles'),fullfile(root,'tests'),'-begin');
assert(~bdIsLoaded('EMT'),'EMS:ModelAlreadyOpen', ...
    'Save and close the currently loaded EMT before validation.');
cfg = baseline_validation_config();
run_dir = tempname(fullfile(root,'results')); mkdir(run_dir);
% Preserve a reviewable copy of every implementation used by this validation.
source_dir = fullfile(run_dir,'source'); mkdir(source_dir);
files = {'run_city200_validation','run_short_simulation','compare_baseline_parameters', ...
    'compare_baseline_outputs','baseline_validation_config','init_reference_params', ...
    'init_baseline_vehicle_params','init_baseline_params','init_transmission_params', ...
    'init_legacy_controller_params','legacy_cycle_arrays'};
for k=1:numel(files), copyfile(which(files{k}),source_dir); end
report = struct('status','running','run_dir',run_dir,'stageD_ready',false, ...
    'scope','Parameter refactor on original EMT; NOT EMT_ML controller parity', ...
    'config',cfg,'started',datestr(now,30));
report.model_sha256 = file_sha256(fullfile(project_root,'EMT.mdl'));
report.parameter_script_sha256 = file_sha256(fullfile(project_root,'parameter.m'));
report.snapshot_sha256 = file_sha256(fullfile(project_root,'parameter.mat'));
save(fullfile(run_dir,'validation_report.mat'),'report');
fprintf('CITY200_VALIDATION_DIR=%s\n',run_dir);
previous_rng = rng; rng_cleanup = onCleanup(@()rng(previous_rng));
try
    assert(test_baseline_comparators());
    reference = init_reference_params();
    candidate = init_baseline_params();
    report.parameters = compare_baseline_parameters(reference,candidate,cfg);
    report.snapshot_parameters = compare_baseline_parameters(reference, ...
        load(fullfile(project_root,'parameter.mat')),cfg);
    writetable(report.parameters,fullfile(run_dir,'parameter_parity.csv'));
    writetable(report.snapshot_parameters,fullfile(run_dir,'snapshot_parity.csv'));
    assert(all(report.parameters.Passed),'EMS:ParameterMismatch', ...
        'Modular parameter mismatch. See parameter_parity.csv.');
    assert(isequal(reference.Time,0:0.1:200),'EMS:WrongCycle','Expected original city200.');
    % Preserve original auxiliary/resistance arrays and interpolation, not constant placeholders.
    assert(isequaln(candidate,init_baseline_params()), ...
        'EMS:NonRepeatableInitialization','Repeated parameter initialization differs.');
    fprintf('1/2: reference initialization, 200 s simulation\n');
    rng(cfg.seed,'twister');
    [original,report.reference_run] = run_short_simulation(project_root,cfg.stop_time,reference);
    save(fullfile(run_dir,'validation_report.mat'),'report');
    fprintf('2/2: modular initialization, 200 s simulation\n');
    rng(cfg.seed,'twister');
    [refactored,report.refactored_run] = run_short_simulation(project_root,cfg.stop_time,candidate);
    report.signals = compare_baseline_outputs(original,refactored,cfg);
    writetable(report.signals,fullfile(run_dir,'signal_parity.csv'));
    report.status = 'failed';
    if all(report.signals.Passed), report.status = 'parameter_refactor_parity_passed'; end
    report.remaining = ['EMT_ML model/controller parity and unresolved wiring warnings ', ...
        'still require audit before stage D.'];
    disp(report.signals);
catch exception
    report.status = 'error';
    report.reason = getReport(exception,'extended','hyperlinks','off');
    save(fullfile(run_dir,'validation_report.mat'),'report');
    fprintf('Validation stopped. Report: %s\n',run_dir);
    rethrow(exception)
end
report.finished = datestr(now,30);
save(fullfile(run_dir,'validation_report.mat'),'report');
fprintf('CITY200_VALIDATION_STATUS=%s\n',report.status);
end
