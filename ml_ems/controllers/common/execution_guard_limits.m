function g=execution_guard_limits(x,o,previous,cfg)
% Observational predictive constraints, NOT a certified plant invariant.
% Te_ref != Te_com; speed dynamics and mode transitions remain approximate.
p=cfg.p;c=cfg.control;dt=c.legacy_Ts;
if isfield(c,'guard_cache') && isequal(x,c.guard_cache_x) && ...
 isequal(o,c.guard_cache_o) && isequal(previous,c.guard_cache_previous)
 g=c.guard_cache;return;
end
ne=x(5);if abs(o(17))>1e-6,ne=9549*o(13)/o(17);end
no=o(2)*(1+p.kh)/p.kh*p.ic/.377/p.rz;
state=struct('ne',ne,'no',no,'te',o(17),'ne_rate',0,'no_rate',0, ...
 'te_rate',0,'engine_input_bias',0,'previous_reference',previous(1), ...
 'pending_engine_reference',previous(2),'ne_acceleration',0,'observation_period',dt, ...
 'synchronous_speed',abs(o(17))>1e-6,'derivative_valid',false);
if isfield(c,'guard_state'),state=c.guard_state;end
g=struct('engine_upper',min(x(9),lookup(p.ne_map,p.Te_max_map,state.ne)), ...
 'engine_actual_limit',lookup(p.ne_map,p.Te_max_map,state.ne), ...
 'speed_lower',x(7),'speed_upper',x(6),'battery_lower',-Inf,'battery_upper',Inf, ...
 'synchronous_speed',state.synchronous_speed,'prediction_valid',false, ...
 'kinematic_infeasible',false,'engine_input_bias',state.engine_input_bias);
% Engine-only correction: model the verified transport delay, actual torque
% lag, speed curvature and a 2 Nm target reserve. Motor/current logic below
% remains unchanged in this focused repair.
g.engine_guard=engine_torque_guard(state,cfg);
g.engine_upper=min(g.engine_upper,g.engine_guard.upper);
% No assumed first-order ne_ref actuator. Reference bounds are only static
% kinematics; candidate torque dynamics are enforced jointly in the QP.
static=motor_speed_feasibility(state,x,o,cfg);
if static.mode_known
 g.speed_lower=max(g.speed_lower,static.static_lower_rpm);
 g.speed_upper=min(g.speed_upper,static.static_upper_rpm);
end
g.prediction_valid=false;
% Separate a real empty steady-state interval from a reduced-model conflict.
% Keep the existing command bounds for this diagnostic-only repair: changing
% torque allocation without observed inner-loop state cannot certify speed.
g.predictive_speed_conflict=g.speed_lower>g.speed_upper;
g.motor_guard=static;
g.motor_prediction=motor_prediction_constraints(x,o,previous,cfg);
g.kinematic_infeasible=g.motor_guard.static_infeasible;
% Enforce current and voltage feasibility in power coordinates, including
% measured actuator lag/disturbance. Never enlarge the original power map.
soc=o(3)/100;ocv=lookup(p.SOC_map/100,p.Uoc_map,soc);
resistance=lookup(p.SOC_map/100,p.R_map,soc);
discharge=min([c.current_max,(ocv-c.voltage_min)/resistance,ocv/(2*resistance)]);
charge=max(-c.current_max,(ocv-c.voltage_max)/resistance);
physicalUpper=(ocv-resistance*discharge)*discharge/1000;
physicalLower=(ocv-resistance*charge)*charge/1000;
measuredMechanical=o(18:19).*o(6:7)/9549;
estimatedElectrical=sum(measuredMechanical.*c.motor_efficiency.^sign(-measuredMechanical))+o(9)+p.PN0+x(18);
disturbance=o(16)-estimatedElectrical;
motorAlpha=exp(-dt/max(p.TS_A,p.TS_B));
g.battery_upper=(physicalUpper-motorAlpha*o(16))/(1-motorAlpha)-disturbance;
g.battery_lower=(physicalLower-motorAlpha*o(16))/(1-motorAlpha)-disturbance;
g.bound_conflict=g.speed_lower>g.speed_upper||g.engine_upper<x(10)||g.battery_lower>g.battery_upper;
end
function value=lookup(axis,table,query)
value=interp1(axis,table,min(max(axis),max(min(axis),query)),'linear');
end
