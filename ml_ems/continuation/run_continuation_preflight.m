function run_continuation_preflight(project_root)
%RUN_CONTINUATION_PREFLIGHT
% Run a short preflight for the continuation EMS experiments.
%
% Usage:
%   projectRoot = 'C:\path\to\revision20';
%   run_continuation_preflight(projectRoot);

if nargin < 1 || isempty(project_root)
    project_root = pwd;
end

project_root = char(project_root);
root = fullfile(project_root,'ml_ems');

assert(isfolder(project_root), ...
    'Project root does not exist: %s',project_root);

assert(isfolder(root), ...
    'ml_ems folder does not exist: %s',root);

% Add all required project folders explicitly.
% The evaluation folder is required by assess_run.
addpath(root,'-begin');
addpath(fullfile(root,'config'),'-begin');
addpath(fullfile(root,'controllers'),'-begin');
addpath(fullfile(root,'controllers','common'),'-begin');
addpath(fullfile(root,'controllers','existing_grid_ems'),'-begin');
addpath(fullfile(root,'controllers','dp'),'-begin');
addpath(fullfile(root,'controllers','ecms'),'-begin');
addpath(fullfile(root,'controllers','mlp_policy'),'-begin');
addpath(fullfile(root,'controllers','lastvalue_cem'),'-begin');
addpath(fullfile(root,'controllers','lstm_cem'),'-begin');
addpath(fullfile(root,'controllers','transformer_cem'),'-begin');
addpath(fullfile(root,'cycles'),'-begin');
addpath(fullfile(root,'models'),'-begin');
addpath(fullfile(root,'continuation'),'-begin');
addpath(fullfile(root,'evaluation'),'-begin');
addpath(fullfile(root,'training'),'-begin');
addpath(fullfile(root,'tests'),'-begin');

rehash path;

% Confirm that the functions used below resolve to this project.
required_functions = { ...
    'experiment_config', ...
    'continuation_config', ...
    'load_cycle', ...
    'controller_registry', ...
    'run_continuation_experiment', ...
    'assess_run'};

for k = 1:numel(required_functions)
    fn = required_functions{k};
    resolved = which(fn);
    assert(~isempty(resolved), ...
        'Required function not found: %s',fn);
    fprintf('%-32s %s\n',fn,resolved);
end

fprintf('\nProject root:\n%s\n\n',project_root);

% Run configuration and basic non-Simulink checks.
fprintf('Running core tests...\n');
test_core;

fprintf('Running result accounting tests...\n');
test_result_accounting;

% Build continuation configuration.
cfg = continuation_config(project_root);

% Use a short simulation for preflight.
cfg.stop_time = 30;
cfg.seed = 20260906;
cfg.initial_soc_percent = 60;
cfg.controller_id = 1;

% Explicitly verify the model required by continuation experiments.
model_file = fullfile(cfg.paths.models,'EMT_ML.slx');

assert(isfile(model_file), ...
    ['Required model not found:\n%s\n' ...
     'Build or restore EMT_ML.slx before running this preflight.'], ...
    model_file);

fprintf('\nContinuation model:\n%s\n',model_file);

% The preflight runs method 1 and method 4 on city200.
ids = [1 4];
runs = cell(1,numel(ids));

for k = 1:numel(ids)
    method = ids(k);

    fprintf('\n========================================\n');
    fprintf('Running city200, controller method %d\n',method);
    fprintf('========================================\n');

    % Re-add evaluation immediately before the experiment call.
    % This protects against any path restoration performed by setup code.
    addpath(fullfile(root,'evaluation'),'-begin');
    rehash path;

    assert(~isempty(which('assess_run')), ...
        'assess_run is not available before continuation experiment.');

    fprintf('assess_run: %s\n',which('assess_run'));

    runs{k} = run_continuation_experiment( ...
        cfg,'city200',method,cfg.seed);

    fprintf('Status: %s\n',runs{k}.status);

    if isfield(runs{k},'acceptance')
        fprintf('Accepted: %d\n',runs{k}.acceptance.accepted);
    end

    if strcmp(runs{k}.status,'failed')
        fprintf('\nRun error:\n%s\n',runs{k}.error);
        error('EMS:PreflightFailed', ...
            'Continuation preflight failed for controller method %d.',method);
    end
end

% Save a compact summary.
summary_folder = create_run_directory( ...
    cfg,'continuation_preflight_summary');

summary = struct;
summary.project_root = project_root;
summary.model_file = model_file;
summary.methods = ids;
summary.runs = cell(size(runs));

for k = 1:numel(runs)
    r = runs{k};

    summary.runs{k} = struct( ...
        'status',r.status, ...
        'folder',r.folder, ...
        'cycle',r.cycle.name, ...
        'controller_id',r.cfg.controller_id, ...
        'controller_name',r.cfg.controller_name, ...
        'metrics',r.metrics, ...
        'acceptance',r.acceptance);

    % Save a copy of each run result into the summary directory.
    if isfile(fullfile(r.folder,'run.mat'))
        copyfile( ...
            fullfile(r.folder,'run.mat'), ...
            fullfile(summary_folder, ...
                sprintf('run_method_%d.mat',ids(k))));
    end

    if isfile(fullfile(r.folder,'status.json'))
        copyfile( ...
            fullfile(r.folder,'status.json'), ...
            fullfile(summary_folder, ...
                sprintf('status_method_%d.json',ids(k))));
    end
end

save(fullfile(summary_folder,'summary.mat'), ...
    'summary','-v7.3');

fprintf('\n========================================\n');
fprintf('Continuation preflight completed.\n');
fprintf('Summary folder:\n%s\n',summary_folder);
fprintf('========================================\n');

end