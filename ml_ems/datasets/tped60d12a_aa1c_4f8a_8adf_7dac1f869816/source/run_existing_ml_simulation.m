function [out,folder,cfg,audit] = run_existing_ml_simulation(project_root,p,cycle)
% Isolated run of the saved EMT_ML with the actual Existing branch selected.
project_root=resolve_baseline_project(project_root);
root=fullfile(project_root,'ml_ems');
assert(~bdIsLoaded('EMT_ML'),'EMS:ModelOpen','Save and close EMT_ML before this check.');
folder=tempname(fullfile(root,'results')); mkdir(folder);
original_path=path; original_dir=pwd; original_gen=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()restore(original_path,original_dir,original_gen));
addpath(root,fullfile(root,'controllers'),fullfile(root,'controllers','common'), ...
    fullfile(root,'models'),fullfile(root,'evaluation'),'-begin');
copyfile(fullfile(root,'models','EMT_ML.slx'),fullfile(folder,'EMT_ML.slx'));
cd(folder);
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
    'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
load_system(fullfile(folder,'EMT_ML.slx'));
for callback={'PreLoadFcn','InitFcn','StopFcn'}
    assert(isempty(get_param('EMT_ML',callback{1})), ...
        'EMS:Callbacks','Unexpected project callback in EMT_ML.');
end
ws=get_param('EMT_ML','ModelWorkspace'); cfg=getVariable(ws,'ems_runtime_config');
cfg.p=p; cfg.controller_id=1; cfg.controller_name='Existing heuristic-grid EMS'; cfg.seed=20260906;
cfg.paths=struct('root',root,'project',project_root,'results',fullfile(root,'results'), ...
    'datasets',fullfile(root,'datasets'),'models',fullfile(root,'models'));
parent='EMT_ML/Control Unit/Control/Power Distribution/Optimal Power Distribution';
op=get_param([parent '/Optimization '],'PortHandles');
sp=get_param([parent '/EMS Controller'],'PortHandles');
rp=get_param([parent '/Rate Transition2'],'PortHandles');
source=@(port)get_param(get_param(port,'Line'),'SrcPortHandle');
assert(source(sp.Inport(1))==source(op.Inport(1)),'EMS:Wiring','19-input sources differ.');
assert(source(sp.Inport(3))==op.Outport(1),'EMS:Wiring','Original action not connected to wrapper port 3.');
assert(source(rp.Inport(1))==sp.Outport(1),'EMS:Wiring','Wrapper does not feed original downstream rate transition.');
assert(strcmp(get_param([parent '/EMS Controller'],'Parameters'),'ems_runtime_config,controller_id'), ...
    'EMS:Selector','Unexpected controller selector binding.');
assert(strcmp(get_param([parent '/EMS Controller'],'FunctionName'),'ems_sfun'),'EMS:Wrapper','Unexpected wrapper.');
audit=struct('input_source_shared',true,'original_action_connected',true,'downstream_connected',true, ...
    'controller_id',1,'wrapper_Ts',.02,'safety_bypassed_for_existing',true);
% Log the upstream original action at the same rate as the existing EMS trace.
logger=[parent '/Parity Original Action'];
add_block('simulink/Sinks/To Workspace',logger,'VariableName','parity_original_action', ...
    'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.02');
lp=get_param(logger,'PortHandles'); add_line(parent,op.Outport(1),lp.Inport(1));
p.Time=cycle.time'; p.v_cyc=cycle.v_ref';
p.Time_ele=cycle.time'; p.ele_map=cycle.aux_power';
p.cycle_time=cycle.time'; p.cycle_grade=cycle.grade';
p.cycle_road=cycle.road_resistance'; p.cycle_steering=cycle.steering_angle';
p.controller_id=1; p.controller_name=cfg.controller_name; p.ems_runtime_config=cfg;
input=Simulink.SimulationInput('EMT_ML'); names=fieldnames(p);
for k=1:numel(names), input=input.setVariable(names{k},p.(names{k}),'Workspace','EMT_ML'); end
input=input.setModelParameter('StopTime',num2str(cycle.time(end),17),'ReturnWorkspaceOutputs','on', ...
    'SaveTime','on','TimeSaveName','tout');
save(fullfile(folder,'run_input.mat'),'p','cycle','cfg','audit');
out=sim(input);
assert(isempty(out.ErrorMessage),'EMS:Simulation','%s',out.ErrorMessage);
t=out.tout; assert(abs(t(end)-cycle.time(end))<1e-6,'EMS:ShortRun','Stop time not reached.');
save(fullfile(folder,'simulation.mat'),'out','-v7.3');
fprintf('ML_EXISTING_COMPLETED=%s\n',folder);
end

function restore(old_path,old_dir,old_gen)
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
Simulink.fileGenControl('setConfig','config',old_gen);
cd(old_dir); path(old_path);
end
