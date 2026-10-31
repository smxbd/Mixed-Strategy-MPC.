function cfg=prepare_evt1_candidate_guard(cfg,x,o,previous,raw)
% Refresh only candidate-dependent motor constraints; keep engine/battery caps.
if ~constraint_guard_enabled(cfg)||~strcmp(cfg.cycle_name,'stress300')||x(4)~=1,return;end
g=execution_guard_limits(x,o,previous,cfg);
g.motor_prediction=evt1_motorA_constraints(x,o,previous,cfg,raw);
cfg.control.guard_cache=g;cfg.control.guard_cache_x=x;
cfg.control.guard_cache_o=o;cfg.control.guard_cache_previous=previous;
end
