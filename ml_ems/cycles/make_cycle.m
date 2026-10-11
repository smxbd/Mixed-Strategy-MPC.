function c=make_cycle(name,time,v)
a=legacy_cycle_arrays; t=time(:);
c=struct('name',char(name),'time',t,'v_ref',v(:),'road_resistance',.045+zeros(size(t)), ...
 'grade',zeros(size(t)),'steering_angle',zeros(size(t)), ...
 'aux_power',interp1(a.aux_time,a.aux,t,'linear','extrap'));
c.units=struct('time','s','v_ref','km/h','road_resistance','dimensionless','grade','rad', ...
 'steering_angle','normalized legacy steering demand','aux_power','kW');
c.version='cycle-v1'; c.seed=0; c.split='test'; c.family=char(name);
c.steering_physical_effect=false;
validate_cycle(c);
end
