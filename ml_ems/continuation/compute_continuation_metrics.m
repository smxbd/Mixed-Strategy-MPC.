function m=compute_continuation_metrics(run,cfg)
t=run.time(:); a=run.trace; o=a(:,20:39);
assert(all(isfinite(t))&&all(diff(t)>0),'EMS:TraceTime','Trace times must strictly increase; no rows are dropped.');
decisionTrace=a;
if isfield(run,'physical')
 t=run.physical.time(:); o=run.physical.signals.values;
 a=interp1(run.time,run.trace,t,'previous','extrap');
end
audit=physical_torque_audit(run,cfg.p);
vref=o(:,1);v=o(:,2);soc=o(:,3)/100;
if isfield(run,'governance')
 assert(isequal(t,run.governance.physical_time));
 vref=run.governance.requested_reference_kmh;
end
d=trapz(t,v)/3600; dr=trapz(t,vref)/3600;
fuel=o(end,20)-o(1,20); err=vref-v;
battPower=o(:,17-1); % observation 16 is Pb_act, kW
batt_kJ=trapz(t,battPower);
if isfield(cfg,'fuel_density_kg_L')
 fuelDensity=cfg.fuel_density_kg_L;
else
 fuelDensity=cfg.fuel_density_kg_per_l;
end
% Match the SOC-adaptive equivalent-fuel factor used by CEM and ECMS.
factor=max(0,cfg.control.ecms_factor + ...
    cfg.control.ecms_soc_gain.*(cfg.control.soc_target-soc));
eq_l=fuel+trapz(t,battPower.*factor/(cfg.LHV_kJ_kg*fuelDensity));
m=struct('fuel_L',fuel,'fuel_L_100km',NaN,'equivalent_fuel_L_100km',NaN, ...
 'delta_SOC_percent',100*(soc(end)-soc(1)),'RMSE_kmh',sqrt(mean(err.^2)), ...
 'max_speed_error_kmh',max(abs(err)),'distance_km',d,'reference_distance_km',dr, ...
 'distance_error_percent',NaN,'engine_starts',sum(diff(o(:,8)>.5)>0), ...
 'mode_switches',sum(diff(a(:,4))~=0),'mean_computation_s',NaN,'max_computation_s',NaN, ...
 'real_time_factor',run.wall_seconds/max(t(end)-t(1),eps), ...
 'fallback_count',NaN,'constraint_violations',NaN,'hard_infeasible_count',NaN, ...
 'voltage_violation_samples',sum(o(:,4)<cfg.control.voltage_min|o(:,4)>cfg.control.voltage_max), ...
 'current_violation_samples',sum(abs(o(:,5))>cfg.control.current_max), ...
 'soc_violation_samples',sum(soc<cfg.control.soc_min|soc>cfg.control.soc_max), ...
 'engine_violation_samples',sum(audit.engine_violation), ...
 'motor_violation_samples',sum(audit.motor_violation), ...
 'control_smoothness',mean(sum(diff(a(:,44:47)).^2,2)),'transmission_efficiency',NaN, ...
 'battery_net_discharge_kJ',batt_kJ);
if d>1e-6, m.fuel_L_100km=100*fuel/d; m.equivalent_fuel_L_100km=100*eq_l/d; end
if dr>1e-6, m.distance_error_percent=100*abs(dr-d)/dr; end
[~,decision]=unique(decisionTrace(:,53),'stable');
m.mean_computation_s=mean(decisionTrace(decision,52)); m.max_computation_s=max(decisionTrace(decision,52));
m.fallback_count=sum(decisionTrace(decision,49)); m.hard_infeasible_count=sum(decisionTrace(decision,51));
if all(isfinite(decisionTrace(decision,50))), m.constraint_violations=sum(decisionTrace(decision,50)>cfg.control.constraint_tolerance); end
m.safety_infeasible_samples=sum(decisionTrace(:,51)>0); m.safety_fallback_samples=sum(decisionTrace(:,49)>0);
if isfield(run,'runtime')&&isstruct(run.runtime)&&isfield(run.runtime,'initialization_s')
 m.initialization_s=run.runtime.initialization_s;
 m.max_full_callback_s=run.runtime.max_callback_s;
 if isfield(run.runtime,'max_decision_wrapper_s')
  m.max_decision_wrapper_s=run.runtime.max_decision_wrapper_s;
  m.max_safety_wrapper_s=run.runtime.max_safety_wrapper_s;
 end
 if isfield(run.runtime,'max_safety_callback_s'), m.max_safety_callback_s=run.runtime.max_safety_callback_s; end
 if isfield(run.runtime,'max_decision_callback_s'), m.max_decision_callback_s=run.runtime.max_decision_callback_s; end
end
if isfield(run,'transmission')
 sig=run.transmission; v=[sig.signals.values]; valid=v(:,1)>1&v(:,2)>=0;
 ein=trapz(sig.time,v(:,1).*valid); eout=trapz(sig.time,v(:,2).*valid);
 if ein>1e-6, m.transmission_efficiency=eout/ein; end
end
m.initial_SOC_percent=o(1,3);m.final_SOC_percent=o(end,3);
m.min_SOC_percent=min(o(:,3));m.max_SOC_percent=max(o(:,3));
m.min_voltage_V=min(o(:,4));m.max_voltage_V=max(o(:,4));m.max_abs_current_A=max(abs(o(:,5)));
m.engine_max_torque_Nm=max(o(:,17));m.engine_max_speed_rpm=max(audit.engine_speed,[],'omitnan');
m.metric_contract_version='synchronous-physical-v2';
m.motorA_nominal_violation_samples=sum(audit.A.nominal_violation);
m.motorB_nominal_violation_samples=sum(audit.B.nominal_violation);
m.motorA_peak_violation_samples=sum(audit.A.peak_violation);
m.motorB_peak_violation_samples=sum(audit.B.peak_violation);
m.motorA_overspeed_samples=sum(audit.A.overspeed);
m.motorB_overspeed_samples=sum(audit.B.overspeed);
m.engine_speed_outside_map_samples=sum(audit.engine_speed_outside);
m.engine_speed_undefined_samples=sum(audit.engine_limit_unknown);
m.engine_max_excess_Nm=max(audit.engine_excess,[],'omitnan');
m.engine_min_reserve_Nm=min(audit.engine_reserve,[],'omitnan');
m.motorA_max_nominal_excess_Nm=max(audit.A.nominal_excess);
m.motorB_max_nominal_excess_Nm=max(audit.B.nominal_excess);
m.motorA_max_peak_excess_Nm=max(audit.A.peak_excess);
m.motorB_max_peak_excess_Nm=max(audit.B.peak_excess);
m.motorA_max_abs_rpm=max(abs(audit.A.speed));m.motorB_max_abs_rpm=max(abs(audit.B.speed));
m.physical_samples=numel(t);m.torque_tolerance_Nm=audit.torque_tolerance_Nm;
m.physical_violation_samples=sum(audit.physical_torque_violation| ...
 o(:,4)<cfg.control.voltage_min|o(:,4)>cfg.control.voltage_max| ...
 abs(o(:,5))>cfg.control.current_max|soc<cfg.control.soc_min|soc>cfg.control.soc_max);
m.engine_speed_source=audit.engine_speed_source;
m.engine_positive_excess_1e_6_samples=sum(audit.engine_excess>1e-6);
m.motorA_positive_nominal_excess_1e_6_samples=sum(audit.A.nominal_excess>1e-6);
m.motorB_positive_nominal_excess_1e_6_samples=sum(audit.B.nominal_excess>1e-6);
m.motorA_positive_peak_excess_1e_6_samples=sum(audit.A.peak_excess>1e-6);
m.motorB_positive_peak_excess_1e_6_samples=sum(audit.B.peak_excess>1e-6);
m.torque_contract='reserve=upper-T; endpoint hold; >1 Nm; nominal and 1.5x peak separate; overspeed separate';
if isfield(run,'runtime')&&isfield(run.runtime,'diagnostics')&&cfg.controller_id~=1
 dg=run.runtime.diagnostics; decision=dg(:,2)>0;
 m.combined_violation_decisions=m.constraint_violations;
 m.constraint_violations=sum(dg(decision,3)>cfg.control.constraint_tolerance);
 m.safety_infeasible_samples=sum(dg(:,3)>cfg.control.constraint_tolerance);
 m.current_state_violation_callbacks=sum(dg(:,4)>cfg.control.constraint_tolerance);
 m.max_command_residual=max(dg(:,3)); m.max_state_residual=max(dg(:,4));
end
m.notes='Equivalent fuel uses declared study LHV/efficiency; command residuals and actual physical excursions are separate. Baseline upstream compiled-chart timing is unmeasured. New EMS timing excludes shared legacy fallback calculation. Transmission boundary signals absent from EMS trace.';
end
