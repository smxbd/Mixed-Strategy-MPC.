function g=engine_torque_guard(state,cfg)
% Predict actual torque AFTER the verified one-safety-tick command delay.
% The original map remains the acceptance limit; reserve is a control target.
p=cfg.p;dt=cfg.control.legacy_Ts;tau=p.Ts_e;
delay=dt;reserve=2;physicalStep=.002;
pending=max(0,state.pending_engine_reference+state.engine_input_bias);
% Saturation precedes the torque lag. An upper bound on the intervening
% map, rather than its minimum, conservatively bounds pending input torque.
[~,pendingMapUpper]=path_limits(state,delay,p);
pending=min(pending,pendingMapUpper);
alpha=exp(-delay/tau);
pendingTorque=alpha*state.te+(1-alpha)*pending;
times=delay+[min(physicalStep,dt),dt:dt:(tau+dt)];
caps=zeros(size(times));limits=zeros(size(times));predictedSpeed=zeros(size(times));
for k=1:numel(times)
 h=times(k);[lower,~]=path_limits(state,h,p);
 target=lower-reserve;
 a=exp(-(h-delay)/tau);
 caps(k)=(target-a*pendingTorque)/(1-a)-state.engine_input_bias;
 limits(k)=lower;predictedSpeed(k)=speed_prediction(state,h);
end
[pendingMapLower,~]=path_limits(state,delay,p);
g=struct('upper',min(caps),'reserve_Nm',reserve,'transport_delay_s',delay, ...
 'pending_torque_prediction_Nm',pendingTorque, ...
 'pending_prediction_excess_Nm',pendingTorque-(pendingMapLower-reserve), ...
 'lookahead_s',times,'reference_caps_Nm',caps, ...
 'minimum_path_limits_Nm',limits,'predicted_rpm',predictedSpeed, ...
 'constant_velocity_rpm',state.ne+times*state.ne_rate, ...
 'version','delay-aware-engine-v3-hull');
end

function ne=speed_prediction(s,h)
% Backward-difference velocity is centered half an observation tick ago.
% This form is exact for a constant-acceleration speed trajectory.
ne=s.ne+h*s.ne_rate+.5*s.ne_acceleration*h*(h+s.observation_period);
end

function [lower,upper]=path_limits(s,h,p)
finish=speed_prediction(s,h);linear=s.ne+h*s.ne_rate;
% A deceleration estimate must not grant early torque rebound: the next
% interval may retain its current velocity. Cover both forecast paths.
left=min([s.ne finish linear]);right=max([s.ne finish linear]);
% Include a possible reversal within the quadratic speed forecast.
if abs(s.ne_acceleration)>eps
 turning=-s.ne_rate/s.ne_acceleration-.5*s.observation_period;
 if turning>0&&turning<h
  vertex=speed_prediction(s,turning);left=min(left,vertex);right=max(right,vertex);
 end
end
knots=p.ne_map(:)';queries=[left right knots(knots>left&knots<right)];
values=interp1(p.ne_map,p.Te_max_map,min(max(p.ne_map),max(min(p.ne_map),queries)),'linear');
lower=min(values);upper=max(values);
end
