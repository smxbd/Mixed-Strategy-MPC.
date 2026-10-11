function [M,offset]=engine_load_relation(x,cfg)
[M,~]=transmission_relations(x,cfg.p);
c=cfg.control;
M(1,:)=M(1,:)/(c.engine_shaft_fraction*c.transmission_efficiency);
offset=c.engine_drag_Nm/c.engine_shaft_fraction;
if x(5)<10, offset=0; end
if isfield(c,'incremental_balance')&&c.incremental_balance&&isfield(c,'dynamic_torque_offset')
 offset=c.dynamic_torque_offset;
end
end
