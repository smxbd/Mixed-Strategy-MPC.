function cfg=update_evt1_motion(cfg,old)
% Extra motor observation only; original engine observer/protection untouched.
if ~constraint_guard_enabled(cfg)||~strcmp(cfg.cycle_name,'stress300'),return;end
g=cfg.control.guard_state;g.no_acceleration=0;g.motor_motion_valid=false;
if ~isempty(old)&&old.stage==g.stage&&old.derivative_valid&&g.derivative_valid
 dt=g.time-old.time;
 if dt>0
  g.no_acceleration=(g.no_rate-old.no_rate)/dt;g.motor_motion_valid=true;
 end
end
cfg.control.guard_state=g;
end
