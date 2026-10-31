function adapt_cycle_inputs(model)
% Identical input adapter for reference test copy and derived model.
% This changes the experiment inputs, never the designated original file.
for pair={{'22932','cycle_road'},{'22940','cycle_grade'}}
 sid=pair{1}{1}; table=pair{1}{2}; b=Simulink.ID.getFullName([model ':' sid]);
 par=get_param(b,'Parent');name=get_param(b,'Name');
 ports=get_param(b,'PortHandles');dst=get_param(get_param(ports.Outport,'Line'),'DstPortHandle');
 delete_line(get_param(ports.Outport,'Line'));delete_block(b);
 add_block('simulink/Lookup Tables/1-D Lookup Table',b, ...
  'BreakpointsForDimension1','cycle_time','Table',table, ...
  'InterpMethod','Linear point-slope','ExtrapMethod','Clip');
 clock=[b '_audit_clock'];add_block('simulink/Sources/Clock',clock);
 add_line(par,[get_param(clock,'Name') '/1'],[name '/1']);
 bp=get_param(b,'PortHandles');for k=1:numel(dst),add_line(par,bp.Outport(1),dst(k));end
end
end
