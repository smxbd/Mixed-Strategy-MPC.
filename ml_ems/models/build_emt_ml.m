function info=build_emt_ml(cfg)
% Rebuild from the pinned original; never edit or save the source model.
[source,sourceHash]=reference_model_source(cfg.paths.project);
folder=create_run_directory(cfg,'reference_rebuild');
old=pwd;oldGen=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()restore(old,oldGen)); %#ok<NASGU>
txt=fileread(source);
for callback={'<P Name="PreLoadFcn">parameter;</P>','<P Name="InitFcn">parameter;</P>', ...
 '<P Name="StopFcn">save(&apos;result.mat&apos;);</P>'}
 assert(count(string(txt),callback{1})==1,'EMS:ReferenceCallback','Original callbacks changed.');
 txt=strrep(txt,callback{1},'');
end
fid=fopen(fullfile(folder,'EMT.mdl'),'w','n','UTF-8');fprintf(fid,'%s',txt);fclose(fid);
cd(folder);Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
 'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
params=fieldnames(cfg.p);for k=1:numel(params),assignin('base',params{k},cfg.p.(params{k}));end
open_system(fullfile(folder,'EMT.mdl'));
destination=fullfile(cfg.paths.models,'EMT_ML.slx');
assert(~isfile(destination),'EMS:NoOverwrite','Build into a fresh candidate directory.');
save_system('EMT',destination);close_system('EMT',0);open_system(destination);
m='EMT_ML';set_param(m,'ReturnWorkspaceOutputs','on','LimitDataPoints','off', ...
 'SignalLoggingSaveFormat','Dataset');
ws=get_param(m,'ModelWorkspace');
for k=1:numel(params),assignin(ws,params{k},cfg.p.(params{k}));end
assignin(ws,'ems_runtime_config',cfg);assignin(ws,'controller_id',1);
assignin(ws,'controller_name',cfg.controller_name);
c=build_city200;assignin(ws,'cycle_time',c.time');assignin(ws,'cycle_road',c.road_resistance');
assignin(ws,'cycle_grade',c.grade');assignin(ws,'cycle_steering',c.steering_angle');
info=add_reference_observers(m);adapt_cycle_inputs(m);
original=Simulink.ID.getFullName([m ':11353']);parent=get_param(original,'Parent');
op=get_param(original,'PortHandles');src=get_param(get_param(op.Inport(1),'Line'),'SrcPortHandle');
rt=Simulink.ID.getFullName([m ':22199']);rp=get_param(rt,'PortHandles');
delete_line(get_param(rp.Inport(1),'Line'));
sf=[parent '/EMS Controller'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',sf, ...
 'FunctionName','ems_sfun','Parameters','ems_runtime_config,controller_id');
% Keep the runtime's existing 20-column ABI. Only the physical log adds ne.
select=[parent '/Runtime Observation Selector'];
add_block('simulink/Signal Routing/Selector',select,'NumberOfDimensions','1', ...
 'IndexOptionArray',{'Index vector (dialog)'},'Indices','1:20','InputPortWidth','21');
add_line(parent,'Physical Observation Bus V2/1','Runtime Observation Selector/1');
sp=get_param(sf,'PortHandles');sel=get_param(select,'PortHandles');
add_line(parent,src,sp.Inport(1));add_line(parent,sel.Outport(1),sp.Inport(2));
add_line(parent,op.Outport(1),sp.Inport(3));
% Existing has a direct original-action route, with no sample-and-hold wrapper.
choose=[parent '/Controller Route'];
add_block('simulink/Signal Routing/Switch',choose,'Criteria','u2 > Threshold','Threshold','1');
constant=[parent '/Controller Selector'];
add_block('simulink/Sources/Constant',constant,'Value','controller_id');
cp=get_param(choose,'PortHandles');kp=get_param(constant,'PortHandles');
add_line(parent,sp.Outport(1),cp.Inport(1));add_line(parent,kp.Outport(1),cp.Inport(2));
add_line(parent,op.Outport(1),cp.Inport(3));add_line(parent,cp.Outport(1),rp.Inport(1));
log=[parent '/EMS Trace'];
add_block('simulink/Sinks/To Workspace',log,'VariableName','ems_trace', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.02');
lp=get_param(log,'PortHandles');add_line(parent,sp.Outport(2),lp.Inport(1));
info.reference_source=source;info.reference_sha256=sourceHash;
info.model=destination;info.status='candidate_built_not_validated';
info.existing_route='original Optimization directly selected before original Rate Transition2';
save_system(m);close_system(m,0);
assert(strcmpi(file_sha256(source),sourceHash),'EMS:ReferenceModified','Original model changed.');
save(fullfile(folder,'build_info.mat'),'info');
end
function restore(old,oldGen)
if bdIsLoaded('EMT'),close_system('EMT',0);end
if bdIsLoaded('EMT_ML'),close_system('EMT_ML',0);end
Simulink.fileGenControl('setConfig','config',oldGen);cd(old);
end
