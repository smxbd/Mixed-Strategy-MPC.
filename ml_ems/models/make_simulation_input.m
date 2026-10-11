function input=make_simulation_input(cfg,c,method)
cfg.controller_id=method; names=controller_registry; cfg.controller_name=names{method};
input=Simulink.SimulationInput('EMT_ML'); p=cfg.p;
p.SOC0=cfg.initial_soc_percent; p.mass=p.mass*cfg.mass_scale;
p.Time=c.time'; p.v_cyc=c.v_ref'; p.Time_ele=c.time'; p.ele_map=c.aux_power';
p.cycle_time=c.time'; p.cycle_grade=c.grade'; p.cycle_road=c.road_resistance'; p.cycle_steering=c.steering_angle';
p.controller_id=method; p.controller_name=cfg.controller_name; p.ems_runtime_config=cfg;
fields=fieldnames(p); for k=1:numel(fields), input=input.setVariable(fields{k},p.(fields{k}),'Workspace','EMT_ML'); end
input=input.setModelParameter('StopTime',num2str(min(c.time(end),cfg.stop_time)),'ReturnWorkspaceOutputs','on','LimitDataPoints','off');
end
