function info=build_emt_ml(cfg)
% Build only from an isolated byte-identical source. Never save the original.
runDir=create_run_directory(cfg,'build'); old=pwd; clean=onCleanup(@()cd(old)); %#ok<NASGU>
copyfile(fullfile(cfg.paths.project,'EMT.mdl'),fullfile(runDir,'EMT.mdl'));
% Harmless callback replacement is resolved in this isolated directory.
fid=fopen(fullfile(runDir,'parameter.m'),'w');
fprintf(fid,'mlp=init_all_params; mln=fieldnames(mlp); for mlk=1:numel(mln), assignin(''base'',mln{mlk},mlp.(mln{mlk})); end\n'); fclose(fid);
images=dir(fullfile(cfg.paths.project,'*.jpg')); for k=1:numel(images), copyfile(fullfile(images(k).folder,images(k).name),runDir); end
cd(runDir); Simulink.fileGenControl('set','CacheFolder',fullfile(runDir,'cache'),'CodeGenFolder',fullfile(runDir,'codegen'),'createDir',true);
load_system(fullfile(runDir,'EMT.mdl'));
set_param('EMT','PreLoadFcn','','InitFcn','','StopFcn','');
destination=fullfile(cfg.paths.models,'EMT_ML.slx');
if isfile(destination), copyfile(destination,fullfile(runDir,'previous_EMT_ML.slx')); end
save_system('EMT',destination); close_system('EMT',0); load_system(destination);
m='EMT_ML'; set_param(m,'PreLoadFcn','','InitFcn','','StopFcn','','ReturnWorkspaceOutputs','on', ...
 'SignalLoggingSaveFormat','Dataset','LimitDataPoints','off','StopTime','200');
ws=get_param(m,'ModelWorkspace'); f=fieldnames(cfg.p); for k=1:numel(f), assignin(ws,f{k},cfg.p.(f{k})); end
assignin(ws,'ems_runtime_config',cfg); assignin(ws,'controller_id',1);
assignin(ws,'controller_name',cfg.controller_name); assignin(ws,'EMSInputBus',create_ems_bus);
c=build_city200; assignin(ws,'cycle_time',c.time'); assignin(ws,'cycle_grade',c.grade');
assignin(ws,'cycle_road',c.road_resistance'); assignin(ws,'cycle_steering',c.steering_angle');
parent=[m '/Control Unit/Control/Power Distribution/Optimal Power Distribution'];
original=[parent '/Optimization ']; op=get_param(original,'PortHandles');
src=get_param(get_param(op.Inport,'Line'),'SrcPortHandle');
rt=[parent '/Rate Transition2']; rtp=get_param(rt,'PortHandles'); delete_line(get_param(rtp.Inport,'Line'));
sf=[parent '/EMS Controller']; add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',sf, ...
 'FunctionName','ems_sfun','Parameters','ems_runtime_config,controller_id','Position',[360 30 530 130]);
mux=[parent '/EMS Observations']; add_block('simulink/Signal Routing/Mux',mux,'Inputs','20','Position',[270 460 275 860]);
tags={'v_com','v_act','SOC','Voltage','Current','nA_act','nB_act','engine_switch','ElectricPower', ...
 'fg_act','angle','Wheel','Pe_act','PA_ele','PB_ele','Pb_act','Te_act','TA_act','TB_act','fuel_L'};
for k=1:numel(tags)
 b=[parent '/Observe_' tags{k}]; add_block('simulink/Signal Routing/From',b,'GotoTag',tags{k},'Position',[10 440+25*k 120 460+25*k]);
 add_line(parent,['Observe_' tags{k} '/1'],['EMS Observations/' num2str(k)]);
end
sp=get_param(sf,'PortHandles'); mp=get_param(mux,'PortHandles');
add_line(parent,src,sp.Inport(1)); add_line(parent,mp.Outport,sp.Inport(2)); add_line(parent,op.Outport,sp.Inport(3));
add_line(parent,sp.Outport(1),rtp.Inport,'autorouting','on');
log=[parent '/EMS Trace']; add_block('simulink/Sinks/To Workspace',log,'VariableName','ems_trace', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.02','Position',[610 150 730 180]);
lp=get_param(log,'PortHandles'); add_line(parent,sp.Outport(2),lp.Inport);
physicalLog=[parent '/Physical Observations']; add_block('simulink/Sinks/To Workspace',physicalLog,'VariableName','physical_observations', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.002','Position',[350 880 500 910]);
lp=get_param(physicalLog,'PortHandles'); add_line(parent,mp.Outport,lp.Inport);
% Dynamic road/grade replace the formerly active constants in the new model only.
replace_constant(m,'22932','cycle_road'); replace_constant(m,'22940','cycle_grade');
info=struct('model',destination,'run_directory',runDir,'status','built','steering_physical_effect',false);
save_system(m); set_param(m,'SimulationCommand','update'); info.status='compiled';
save(fullfile(runDir,'build_info.mat'),'info'); close_system(m,0);
end
function replace_constant(model,sid,table)
b=Simulink.ID.getFullName([model ':' sid]); par=get_param(b,'Parent'); pos=get_param(b,'Position');
ports=get_param(b,'PortHandles'); dst=get_param(get_param(ports.Outport,'Line'),'DstPortHandle');
delete_line(get_param(ports.Outport,'Line')); delete_block(b);
add_block('simulink/Lookup Tables/1-D Lookup Table',b,'BreakpointsForDimension1','cycle_time','Table',table,'Position',pos);
clock=[b '_clock']; add_block('simulink/Sources/Clock',clock,'Position',pos-[70 0 70 0]);
bp=get_param(b,'PortHandles'); cp=get_param(clock,'PortHandles'); add_line(par,cp.Outport,bp.Inport);
for k=1:numel(dst), add_line(par,bp.Outport,dst(k)); end
end
