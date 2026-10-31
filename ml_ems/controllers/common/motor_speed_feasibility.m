function g=motor_speed_feasibility(state,x,o,cfg)
% Exact steady kinematics; observational forecasts do NOT certify a command.
% ne_ref is an input to upstream torque allocation, not a speed actuator.
p=cfg.p;dt=cfg.control.legacy_Ts;
g=struct('mode_known',ismember(x(4),[1 3]),'static_lower_rpm',p.ne_min, ...
 'static_upper_rpm',p.ne_max,'static_infeasible',false, ...
 'forecast_times_s',[dt 2*dt],'forecast_motor_rpm',nan(2,2), ...
 'forecast_excess_rpm',nan(2,2),'kinematic_residual_rpm',[NaN;NaN], ...
 'command_response_certified',false,'forecast_valid',false, ...
 'reason','unobserved_mode_dynamics');
if ~g.mode_known,return;end
if x(4)==3
 a=[p.a21;p.b21];b=[p.a22;p.b22];
else
 a=[p.a11;p.b11];b=[p.a12;p.b12];
end
limits=[p.nA_max;p.nB_max];
g.kinematic_residual_rpm=o(6:7)'-a*state.ne-b*state.no;
for k=1:2
 if abs(a(k))<1e-12
  if abs(b(k)*state.no)>limits(k),g.static_upper_rpm=-Inf;end
 else
  edges=([-limits(k) limits(k)]-b(k)*state.no)/a(k);
  g.static_lower_rpm=max(g.static_lower_rpm,min(edges));
  g.static_upper_rpm=min(g.static_upper_rpm,max(edges));
 end
end
g.static_infeasible=g.static_lower_rpm>g.static_upper_rpm;
h=g.forecast_times_s;
% The first endpoint is the next callback; the second is the first full
% safety interval after the one-tick transport delay. No fictitious gain
% from a newly issued speed reference is included in either forecast.
ne=state.ne+h*state.ne_rate+.5*state.ne_acceleration*h.*(h+state.observation_period);
no=state.no+h*state.no_rate;
g.forecast_motor_rpm=a*ne+b*no+g.kinematic_residual_rpm;
g.forecast_excess_rpm=max(0,abs(g.forecast_motor_rpm)-limits);
g.forecast_valid=state.derivative_valid;
if g.static_infeasible,g.reason='static_motor_speed_interval_empty';
elseif ~g.forecast_valid,g.reason='speed_derivatives_unavailable';
else,g.reason='speed_command_response_unverified';end
end
