function [out,run_dir] = run_short_simulation(project_root,stop_time,parameter_override)
% Run the unchanged plant/controller with an explicit parameter MAT snapshot.
if nargin < 1, project_root = []; end
if nargin < 2, stop_time = 30; end
project_root = resolve_baseline_project(project_root);
validateattributes(stop_time,{'numeric'},{'scalar','finite','positive'});
% Never close or replace a model the user already has open.
assert(~bdIsLoaded('EMT'),'EMS:ModelAlreadyOpen', ...
    'EMT is already loaded. Save your work and close EMT before running this isolated check.');
results_dir = fullfile(project_root,'ml_ems','results');
if ~isfolder(results_dir), mkdir(results_dir); end
run_dir = tempname(results_dir);
mkdir(run_dir);
if nargin < 3
    params = load(fullfile(project_root,'parameter.mat'));
    parameter_source = 'project parameter.mat snapshot';
else
    validateattributes(parameter_override,{'struct'},{'scalar'});
    params = parameter_override;
    parameter_source = 'explicit parameter_override; see parent validation report';
end
save(fullfile(run_dir,'parameter_snapshot.mat'),'params');
% Remove only the three verified project-level callbacks, before model loading.
source = fileread(fullfile(project_root,'EMT.mdl'));
callbacks = {'<P Name="PreLoadFcn">parameter;</P>', ...
    '<P Name="InitFcn">parameter;</P>', ...
    '<P Name="StopFcn">save(&apos;result.mat&apos;);</P>'};
for k = 1:numel(callbacks)
    assert(count(string(source),callbacks{k}) == 1,'EMS:CallbackChanged', ...
        'Expected model callback changed. Inspect the model before running: %s',callbacks{k});
    source = strrep(source,callbacks{k},'');
end
model_file = fullfile(run_dir,'EMT.mdl');
fid = fopen(model_file,'w','n','UTF-8');
assert(fid >= 0,'EMS:WriteFailed','Cannot create isolated model: %s',model_file);
file_cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',source);
clear file_cleanup
previous_dir = pwd;
previous_path = path;
previous_codegen = Simulink.fileGenControl('getConfig');
cleanup = onCleanup(@()restore_environment(previous_dir,previous_path,previous_codegen));
addpath(project_root);
cd(run_dir);
Simulink.fileGenControl('set','CacheFolder',fullfile(run_dir,'cache'), ...
    'CodeGenFolder',fullfile(run_dir,'codegen'),'createDir',true);
metadata = struct('source_model',fullfile(project_root,'EMT.mdl'), ...
    'parameter_source',parameter_source, ...
    'stop_time',stop_time,'status','running','release',version, ...
    'note','Unchanged control/plant. Only project callbacks isolated; warnings retained.');
save(fullfile(run_dir,'run_metadata.mat'),'metadata');
try
    load_system(model_file);
    input = Simulink.SimulationInput('EMT');
    names = fieldnames(params);
    for k = 1:numel(names)
        input = input.setVariable(names{k},params.(names{k}));
    end
    input = input.setModelParameter('StopTime',num2str(stop_time,17), ...
        'ReturnWorkspaceOutputs','on','SaveTime','on','TimeSaveName','tout');
    out = sim(input);
    assert(isempty(out.ErrorMessage),'EMS:SimulationFailed','%s',out.ErrorMessage);
    t = out.get('tout');
    assert(~isempty(t) && abs(t(end)-stop_time) < 1e-6, ...
        'EMS:IncompleteRun','Simulation did not reach requested stop time.');
    save(fullfile(run_dir,'short_simulation_output.mat'),'out','-v7.3');
    metadata.status = 'completed';
catch exception
    metadata.status = 'error';
    metadata.reason = getReport(exception,'extended','hyperlinks','off');
    save(fullfile(run_dir,'run_metadata.mat'),'metadata');
    fprintf('Failed run details: %s\n',run_dir);
    rethrow(exception)
end
save(fullfile(run_dir,'run_metadata.mat'),'metadata');
fprintf('Completed simulation saved in: %s\n',run_dir);
end

function restore_environment(previous_dir,previous_path,previous_codegen)
if bdIsLoaded('EMT'), close_system('EMT',0); end
Simulink.fileGenControl('setConfig','config',previous_codegen);
cd(previous_dir);
path(previous_path);
end
