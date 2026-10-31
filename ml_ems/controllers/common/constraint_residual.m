function [r,pb,detail]=constraint_residual(u,x,o,previous,cfg)
p=cfg.p; c=cfg.control; [M,offset]=engine_load_relation(x,cfg);
motorP=u(:,3:4).*[o(6) o(7)]/9549;
elec=motorP.*c.motor_efficiency.^sign(-motorP); pb=sum(elec,2)+o(9)+p.PN0+x(18);
v=o(4); soc=o(3)/100;
pbmax=interp1(p.Voltage_epr,p.Pb_max,min(1050,max(750,v)));
pbmin=interp1(p.Voltage_epr,p.Pb_min,min(1050,max(750,v)));
if soc<=c.soc_min, pbmax=min(pbmax,0); end
if soc>=c.soc_max, pbmin=max(pbmin,0); end
teMax=min(x(9),interp1(p.ne_map,p.Te_max_map,min(4500,max(1600,x(5)))));
guarded=constraint_guard_enabled(cfg);
if guarded
 guard=execution_guard_limits(x,o,previous,cfg);
 teMax=min(teMax,guard.engine_upper);
 pbmin=max(pbmin,guard.battery_lower);pbmax=min(pbmax,guard.battery_upper);
end
rate=abs(u-previous)-c.rate*c.Ts;
commandTerms=[x(7)-u(:,1),u(:,1)-x(6),x(10)-u(:,2),u(:,2)-teMax, ...
 x(12)-u(:,3),u(:,3)-x(11),x(14)-u(:,4),u(:,4)-x(13), ...
 pbmin-pb,pb-pbmax,abs(u(:,2)-u(:,3:4)*M(1,:)'-offset)-c.torque_balance_tolerance, ...
 max(rate,[],2)];
state=max([abs(o(6))-p.nA_max,abs(o(7))-p.nB_max, ...
 c.voltage_min-v,v-c.voltage_max,(c.soc_min-soc)*100,(soc-c.soc_max)*100,abs(o(5))-c.current_max,0]);
if guarded
 commandTerms=[commandTerms,guard.speed_lower-u(:,1),u(:,1)-guard.speed_upper];
 % A reference torque cap cannot certify the measured actuator output.
 state=max(state,o(17)-guard.engine_actual_limit);
end
dynamic=false;
if guarded && guard.motor_prediction.active
 dynamic=true;
 % The original heuristic offset is not a Newton balance constraint.
 % Replace it with the torque-driven rotor prediction inequalities.
 commandTerms(:,11)=-Inf;
 commandTerms=[commandTerms,u*guard.motor_prediction.A'-guard.motor_prediction.b'];
end
command=max(0,max(commandTerms,[],2)); command(any(~isfinite(u),2))=Inf;
r=max(command,state);
% The legacy-reference residual remains visible even in experimental mode.
projectionCommand=command;
if isfield(c,'reference_balance_soft') && c.reference_balance_soft
 projectionCommand=max(0,max(commandTerms(:,[1:10 12:size(commandTerms,2)]),[],2));
 projectionCommand(any(~isfinite(u),2))=Inf;
end
detail=struct('command',command,'state',state,'terms',commandTerms, ...
 'projection_command',projectionCommand);
% Stable names make each infeasible callback auditable without re-deriving
% the residual vector from a saved trace.
detail.term_names={'engine_lower','engine_upper','engine_torque_lower','engine_torque_upper', ...
 'motorA_lower','motorA_upper','motorB_lower','motorB_upper','battery_lower', ...
 'battery_upper','torque_balance','rate'};
if guarded
 detail.term_names=[detail.term_names,{'motor_speed_reference_lower','motor_speed_reference_upper'}];
 if dynamic
  detail.term_names=[detail.term_names,arrayfun(@(k)sprintf('predicted_motor_speed_%d',k),1:size(guard.motor_prediction.A,1),'UniformOutput',false)];
 end
 detail.guard=guard;
end
detail.active_terms=max(commandTerms,[],1)>c.constraint_tolerance;
detail.active_state=[abs(o(6))-p.nA_max,abs(o(7))-p.nB_max,c.voltage_min-v, ...
 v-c.voltage_max,(c.soc_min-soc)*100,(soc-c.soc_max)*100,abs(o(5))-c.current_max,0] > c.constraint_tolerance;
if guarded
 detail.active_state(8)=o(17)-guard.engine_actual_limit>c.constraint_tolerance;
end
end
