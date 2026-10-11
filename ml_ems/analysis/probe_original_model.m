function probe_original_model(runDir)
% Stage A: run ONLY in an isolated copy; never save or simulate the source.
arguments
    runDir (1,:) char
end
manifestPath = fullfile(runDir,'isolation_manifest.json');
assert(isfile(manifestPath),'Use run_stage_a_audit.ps1 to create an isolated copy first.');
isolation = jsondecode(fileread(manifestPath));
expectedParent = char(java.io.File(fullfile(isolation.project_root, ...
    'ml_ems','analysis','runtime')).getCanonicalPath());
actualParent = char(java.io.File(fileparts(runDir)).getCanonicalPath());
assert(strcmpi(expectedParent,actualParent),'Audit directory must be inside ml_ems/analysis/runtime.');
assert(isfile(fullfile(runDir,'EMT.mdl')), 'Isolated EMT.mdl missing.');
assert(isfile(fullfile(runDir,'parameter.m')), 'Isolated parameter.m missing.');
oldDir = pwd;
restoreDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>
cd(runDir);
set(groot,'DefaultFigureVisible','off');
diary(fullfile(runDir,'matlab_diary.txt'));
diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>
audit = struct('release',version('-release'),'version',version, ...
    'computer',computer,'run_directory',runDir,'started_at',char(datetime('now')), ...
    'load_status','not_run','compile_status','not_run','simulation_status','not_run');
audit.products = ver;
features = {'MATLAB','SIMULINK','Stateflow','Simscape','SimDriveline', ...
    'Power_System_Blocks','Neural_Network_Toolbox','Distrib_Computing_Toolbox'};
for k=1:numel(features)
    audit.licenses.(features{k}) = license('test',features{k});
end
audit.original_mex_on_path = which('EMT_sfun');
try
    Simulink.fileGenControl('set','CacheFolder',fullfile(runDir,'cache'), ...
        'CodeGenFolder',fullfile(runDir,'codegen'),'createDir',true);
    timer = tic;
    load_system(fullfile(runDir,'EMT.mdl'));
    audit.load_seconds = toc(timer);
    audit.load_status = 'passed';
    audit.loaded_filename = get_param('EMT','FileName');
    keys = {'PreLoadFcn','InitFcn','StopFcn','SolverType','Solver','FixedStep', ...
        'StopTime','SimulationMode','SignalLogging','ReturnWorkspaceOutputs'};
    for k=1:numel(keys)
        audit.model_configuration.(keys{k}) = get_param('EMT',keys{k});
    end
    audit.top_level_blocks = find_system('EMT','SearchDepth',1,'Type','block');
    audit.optimization_blocks = find_system('EMT','LookUnderMasks','all', ...
        'FollowLinks','off','RegExp','on','Name','^Optimization');
    save(fullfile(runDir,'runtime_audit.mat'),'audit');
    write_json(fullfile(runDir,'runtime_audit.json'),audit);
    try
        timer = tic;
        feval('EMT',[],[],[],'compile');
        audit.compile_seconds = toc(timer);
        audit.compile_status = 'passed';
        for k=1:numel(audit.optimization_blocks)
            block = audit.optimization_blocks{k};
            audit.optimization_compiled(k).path = block;
            audit.optimization_compiled(k).sample_time = get_param(block,'CompiledSampleTime');
            audit.optimization_compiled(k).port_dimensions = get_param(block,'CompiledPortDimensions');
        end
        audit.compiled_sample_times = Simulink.BlockDiagram.getSampleTimes('EMT');
        feval('EMT',[],[],[],'term');
    catch ME
        audit.compile_status = 'failed';
        audit.compile_error_id = ME.identifier;
        audit.compile_error = getReport(ME,'extended','hyperlinks','off');
        try, feval('EMT',[],[],[],'term'); catch, end
    end
catch ME
    audit.load_status = 'failed';
    audit.load_error_id = ME.identifier;
    audit.load_error = getReport(ME,'extended','hyperlinks','off');
end
audit.finished_at = char(datetime('now'));
save(fullfile(runDir,'runtime_audit.mat'),'audit');
try, write_json(fullfile(runDir,'runtime_audit.json'),audit); catch ME, disp(ME.message); end
disp(audit);
if bdIsLoaded('EMT'), close_system('EMT',0); end
close all force;
end

function write_json(path,value)
fid = fopen(path,'w','n','UTF-8');
assert(fid~=-1,'Cannot open audit JSON.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
