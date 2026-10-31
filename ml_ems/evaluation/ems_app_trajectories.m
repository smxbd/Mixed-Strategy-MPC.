function data=ems_app_trajectories(run)
% Export physical trajectories on their original, synchronous timestamps.
[t,o,ne]=synchronized_physical_observations(run);
data=table(t,o(:,1),o(:,2),o(:,3),o(:,20)-o(1,20),ne,o(:,13),o(:,16), ...
 'VariableNames',{'time_s','reference_kmh','speed_kmh','SOC_percent', ...
 'fuel_L','engine_rpm','engine_kW','battery_kW'});
if isfield(run,'governance')
 data.reference_kmh=run.governance.requested_reference_kmh;
 data.safe_reference_kmh=run.governance.safe_reference_kmh;
 data.reference_reduction_kmh=run.governance.reference_reduction_kmh;
end
end
