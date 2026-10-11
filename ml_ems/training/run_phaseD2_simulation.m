function [out,folder,cfg]=run_phaseD2_simulation(project_root,p,cycle,method,cfg)
%RUN_PHASED2_SIMULATION Run one selected controller in a disposable EMT_ML copy.
project_root=resolve_baseline_project(project_root);
root=fullfile(project_root,'ml_ems');
assert(~bdIsLoaded('EMT_ML'),'EMS:ModelOpen','Close EMT_ML before phase D2 simulation.');
names=controller_registry;
assert(method>=1&&method<=numel(names),'EMS:Controller','Unknown controller ID.');
folder=tempname(fullfile(root,'results')); mkdir(folder);
oldPath=path; oldDir=pwd; oldGen=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()restore(oldPath,oldDir,oldGen)); %#ok<NASGU>
addpath(root,fullfile(root,'config'),fullfile(root,'cycles'),fullfile(root,'models'), ...
    fullfile(root,'evaluation'),fullfile(root,'training'),fullfile(root,'controllers'), ...
    fullfile(root,'controllers','common'),fullfile(root,'controllers','ecms'), ...
    fullfile(root,'controllers','dp'),'-begin');
copyfile(fullfile(root,'models','EMT_ML.slx'),fullfile(folder,'EMT_ML.slx'));
cd(folder);
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
    'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
load_system(fullfile(folder,'EMT_ML.slx'));
cfg.p=p; cfg.controller_id=method; cfg.controller_name=names{method};
if method==2, cfg.dp_plan=solve_dp(cycle,cfg); end
runtime=cfg;
q=p;
q.Time=cycle.time'; q.v_cyc=cycle.v_ref';
q.Time_ele=cycle.time'; q.ele_map=cycle.aux_power';
q.cycle_time=cycle.time'; q.cycle_grade=cycle.grade';
q.cycle_road=cycle.road_resistance'; q.cycle_steering=cycle.steering_angle';
q.controller_id=method; q.controller_name=cfg.controller_name; q.ems_runtime_config=runtime;
input=Simulink.SimulationInput('EMT_ML'); fields=fieldnames(q);
for k=1:numel(fields), input=input.setVariable(fields{k},q.(fields{k}),'Workspace','EMT_ML'); end
input=input.setModelParameter('StopTime',num2str(cycle.time(end),17),'ReturnWorkspaceOutputs','on', ...
    'SaveTime','on','TimeSaveName','tout','LimitDataPoints','off');
save(fullfile(folder,'run_input.mat'),'q','cycle','runtime','method','-v7.3');
out=sim(input);
assert(isempty(out.ErrorMessage),'EMS:Simulation','%s',out.ErrorMessage);
assert(abs(out.tout(end)-cycle.time(end))<1e-6,'EMS:StopTime','Simulation did not reach stop time.');
save(fullfile(folder,'simulation.mat'),'out','-v7.3');
fprintf('PHASED2_SIMULATION_COMPLETED=%s\n',folder);
end

function restore(oldPath,oldDir,oldGen)
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
Simulink.fileGenControl('setConfig','config',oldGen);
cd(oldDir); path(oldPath);
end
