function a=assess_run(run,cfg)
a=struct('simulation_completed',strcmp(run.status,'completed'),'hard_commands_pass',false,'physical_limits_pass',false, ...
 'online_budget_pass',false,'tracking_comparable',false,'accepted',false);
if ~isfield(run,'metrics')||isempty(fieldnames(run.metrics)), return; end
m=run.metrics;
a.hard_commands_pass=isfinite(m.constraint_violations)&&m.constraint_violations==0;
if isfield(m,'safety_infeasible_samples'), a.hard_commands_pass=a.hard_commands_pass&&m.safety_infeasible_samples==0; end
a.physical_limits_pass=m.physical_violation_samples==0;
a.online_budget_pass=isfinite(m.max_computation_s)&&m.max_computation_s<=cfg.control.Ts;
if isfield(m,'max_decision_callback_s'), a.online_budget_pass=a.online_budget_pass&&m.max_decision_callback_s<=cfg.control.Ts; end
if isfield(m,'max_safety_callback_s'), a.online_budget_pass=a.online_budget_pass&&m.max_safety_callback_s<=cfg.control.legacy_Ts; end
if isfield(cfg,'reference_RMSE'), a.tracking_comparable=m.RMSE_kmh<=cfg.reference_RMSE+.25; end
a.accepted=a.simulation_completed&&a.hard_commands_pass&&a.physical_limits_pass&&a.online_budget_pass&&a.tracking_comparable;
a.note='Simulation completion is not acceptance. Tracking needs a paired same-cycle baseline; baseline compute time is unmeasured.';
end
