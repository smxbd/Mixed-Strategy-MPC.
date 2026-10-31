function info=add_reference_observers(model)
% Read-only observation branches, preserving every original physical block.
parent=get_param(Simulink.ID.getFullName([model ':11353']),'Parent');
tags={'v_com','v_act','SOC','Voltage','Current','nA_act','nB_act','engine_switch', ...
 'ElectricPower','fg_act','angle','Wheel','Pe_act','PA_ele','PB_ele','Pb_act', ...
 'Te_act','TA_act','TB_act','fuel_L','ne_act'};
mux=[parent '/Physical Observation Bus V2'];
add_block('simulink/Signal Routing/Mux',mux,'Inputs','21');
for k=1:numel(tags)
 b=[parent '/Physical V2 ' tags{k}];
 add_block('simulink/Signal Routing/From',b,'GotoTag',tags{k});
 add_line(parent,['Physical V2 ' tags{k} '/1'],['Physical Observation Bus V2/' num2str(k)]);
end
logger=[parent '/Physical Observations V2'];
add_block('simulink/Sinks/To Workspace',logger,'VariableName','physical_observations', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.002');
add_line(parent,'Physical Observation Bus V2/1','Physical Observations V2/1');
% Original action is logged independently of the controller wrapper.
action=[parent '/Original Action Audit'];
add_block('simulink/Sinks/To Workspace',action,'VariableName','original_action_audit', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.002');
op=get_param(Simulink.ID.getFullName([model ':11353']),'PortHandles');
lp=get_param(action,'PortHandles');add_line(parent,op.Outport(1),lp.Inport(1));
legacy=[parent '/Legacy State Audit'];
add_block('simulink/Sinks/To Workspace',legacy,'VariableName','legacy_state_audit', ...
 'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','0.02');
lp=get_param(legacy,'PortHandles');
src=get_param(get_param(op.Inport(1),'Line'),'SrcPortHandle');add_line(parent,src,lp.Inport(1));
info=struct('schema',2,'columns',{tags},'physical_interval_s',.002);
end
