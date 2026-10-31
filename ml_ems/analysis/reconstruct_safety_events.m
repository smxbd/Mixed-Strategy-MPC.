function events=reconstruct_safety_events(run)
% Offline only. Rebuild protection details from ALL fixed-buffer callbacks.
cfg=run.cfg;inputs=run.runtime.safety_inputs;diag=run.runtime.diagnostics;
times=run.runtime.projection_times;events=[];
if isfield(cfg.control,'guard_state'),cfg.control=rmfield(cfg.control,'guard_state');end
if isfield(cfg.control,'guard_cache'),cfg.control=rmfield(cfg.control,'guard_cache');end
for k=1:size(inputs,1)
 if isfield(cfg.control,'guard_cache'),cfg.control=rmfield(cfg.control,'guard_cache');end
 row=inputs(k,:);t=row(1);x=row(2:20);o=row(21:40);
 original=row(41:44);raw=row(45:48);u=row(49:52);previous=row(53:56);
 [M,~]=engine_load_relation(x,cfg);
 cfg.control.dynamic_torque_offset=original(2)-M(1,:)*original(3:4)';
 old=[];if isfield(cfg.control,'guard_state'),old=cfg.control.guard_state;end
 cfg=update_constraint_guard(cfg,t,x,o,previous);cfg=update_evt1_motion(cfg,old);cfg.control.Ts=row(57);
 cfg=prepare_evt1_candidate_guard(cfg,x,o,previous,raw);
 if diag(k,3)<=cfg.control.constraint_tolerance&&diag(k,4)<=cfg.control.constraint_tolerance&&times(k,3)==0,continue;end
 [res,~,d]=constraint_residual(u,x,o,previous,cfg);
 fallback=double(times(k,3)>0);reason='command_constraint';
 if d.guard.motor_guard.static_infeasible,reason='static_motor_speed_interval_empty';
 elseif ~d.guard.motor_guard.mode_known,reason='unobserved_mode_dynamics';
 elseif d.guard.bound_conflict,reason='predictive_bounds_infeasible';
 elseif d.state>cfg.control.constraint_tolerance&&d.command<=cfg.control.constraint_tolerance,reason='measured_state_constraint';
 elseif fallback,reason='no_feasible_candidate_fallback';end
 ev=struct('time',t,'decision',row(58),'requested_action',raw,'applied_action',u, ...
  'command_violation',d.command,'state_violation',d.state,'constraint_violation',res, ...
  'fallback_flag',fallback,'infeasibility_reason',reason,'guard',d.guard, ...
  'demand_loss',raw(2)-u(2),'elapsed_seconds',diag(k,5));
 if isempty(events),events=ev;else,events(end+1)=ev;end %#ok<AGROW>
end
end
