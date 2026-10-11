function validate_cycle(c)
assert(all(diff(c.time)>0)&&c.time(1)==0,'Cycle time must start at zero and increase.');
for field={'v_ref','road_resistance','grade','steering_angle','aux_power'}
 x=c.(field{1}); assert(numel(x)==numel(c.time)&&all(isfinite(x)),'Invalid cycle channel %s',field{1});
end
assert(all(c.v_ref>=0)&all(c.v_ref<=120));
assert(all(c.road_resistance>=0)&all(c.road_resistance<=.2));
assert(all(abs(c.grade)<.3)&all(c.aux_power>=0));
end
