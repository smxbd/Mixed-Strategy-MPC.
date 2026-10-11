function m=compute_continuation_metrics(run,cfg)
t=run.time(:); a=run.trace; o=a(:,20:39);
[t,ix]=unique(t,'stable'); a=a(ix,:); o=o(ix,:);
decisionTrace=a;
if isfield(run,'physical')
 t=run.physical.time(:); o=run.physical.signals.values;
 a=interp1(run.time,run.trace,t,'previous','extrap');
end
vref=o(:,1); v=o(:,2); soc=o(:,3)/100;
d=trapz(t,v)/3600; dr=trapz(t,vref)/3600;
fuel=o(end,20)-o(1,20); err=vref-v;
batt_kJ=trapz(t,o(:,17-1)); % observation 16 is Pb_act, kW
if isfield(cfg,'fuel_density_kg_L')
 fuelDensity=cfg.fuel_density_kg_L;
else
 fuelDensity=cfg.fuel_density_kg_per_l;
end
eq_l=fuel+batt_kJ/(cfg.eta_eq*cfg.LHV_kJ_kg*fuelDensity);
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
 'engine_violation_samples',sum(o(:,17)>interp1(cfg.p.ne_map,cfg.p.Te_max_map,a(:,5),'linear','extrap')+1), ...
 'motor_violation_samples',sum(abs(o(:,6))>cfg.p.nA_max|abs(o(:,7))>cfg.p.nB_max|abs(o(:,18))>interp1(cfg.p.nA_map,cfg.p.TA_max_map,o(:,6),'linear','extrap')+1|abs(o(:,19))>interp1(cfg.p.nB_map,cfg.p.TB_max_map,o(:,7),'linear','extrap')+1), ...
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
 if isfield(run.runtime,'max_safety_callback_s'), m.max_safety_callback_s=run.runtime.max_safety_callback_s; end
 if isfield(run.runtime,'max_decision_callback_s'), m.max_decision_callback_s=run.runtime.max_decision_callback_s; end
end
if isfield(run,'transmission')
 sig=run.transmission; v=[sig.signals.values]; valid=v(:,1)>1&v(:,2)>=0;
 ein=trapz(sig.time,v(:,1).*valid); eout=trapz(sig.time,v(:,2).*valid);
 if ein>1e-6, m.transmission_efficiency=eout/ein; end
end
m.physical_violation_samples=m.voltage_violation_samples+m.current_violation_samples+m.soc_violation_samples+m.engine_violation_samples+m.motor_violation_samples;
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
