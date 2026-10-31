function cfg=update_constraint_guard(cfg,t,x,o,previous)
% Observe the existing bus only. No new model ports or plant changes.
if ~constraint_guard_enabled(cfg),return;end
ne=x(5);synchronous=abs(o(17))>1e-6;
if synchronous,ne=9549*o(13)/o(17);end
no=o(2)*(1+cfg.p.kh)/cfg.p.kh*cfg.p.ic/.377/cfg.p.rz;
g=struct('time',t,'stage',x(4),'ne',ne,'no',no,'te',o(17), ...
 'ne_rate',0,'no_rate',0,'te_rate',0,'engine_input_bias',0, ...
 'ne_acceleration',0,'observation_period',cfg.control.legacy_Ts, ...
 'pending_engine_reference',previous(2), ...
 'previous_reference',previous(1),'synchronous_speed',synchronous, ...
 'derivative_valid',false,'version','delay-aware-engine-v2');
if isfield(cfg.control,'guard_state')
 old=cfg.control.guard_state;dt=t-old.time;
 if dt>0&&old.stage==g.stage
  g.no_rate=(no-old.no)/dt;g.te_rate=(g.te-old.te)/dt;
  if synchronous&&old.synchronous_speed,g.ne_rate=(ne-old.ne)/dt;end
  g.derivative_valid=synchronous&&old.synchronous_speed;
  g.observation_period=dt;
  if g.derivative_valid&&old.derivative_valid
   g.ne_acceleration=(g.ne_rate-old.ne_rate)/dt;
  end
  % The previous physical interval used old.pending_engine_reference,
  % not the newer reference waiting at the Rate Transition output.
  % Exact ZOH inversion avoids the backward-Euler bias of Te+tau*dTe/dt.
  alpha=exp(-dt/cfg.p.Ts_e);
  equivalentInput=(g.te-alpha*old.te)/(1-alpha);
  g.engine_input_bias=max(0,equivalentInput-old.pending_engine_reference);
  % Negative residuals can be caused by pre-lag saturation; treating them
  % as extra control authority would unsafely enlarge the torque cap.
 end
end
cfg.control.guard_state=g;
end
