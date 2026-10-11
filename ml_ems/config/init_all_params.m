function p=init_all_params
p=init_vehicle_params;
p=init_transmission_params(p);
p=init_legacy_controller_params(p);
c=legacy_cycle_arrays;
p.Time=c.time; p.v_cyc=c.v; p.Time_fg=c.road_time; p.fg_map=c.road;
p.Time_ele=c.aux_time; p.ele_map=c.aux;
end
