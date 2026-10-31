function a=physical_torque_audit(run,p)
% Shared physical accounting contract: endpoint hold; >1 N m; peak=1.5x.
[a.time,o,a.engine_speed,a.engine_speed_source]=synchronized_physical_observations(run);
a.torque_tolerance_Nm=1; a.speed_tolerance_rpm=1e-6;
a.engine_speed_valid=isfinite(a.engine_speed);
a.engine_limit=lookup(p.ne_map,p.Te_max_map,a.engine_speed);
a.engine_reserve=a.engine_limit-o(:,17); % positive means available reserve
a.engine_excess=-a.engine_reserve;
a.engine_violation=a.engine_excess>a.torque_tolerance_Nm;
a.engine_speed_outside=a.engine_speed_valid & ...
 (a.engine_speed<p.ne_map(1)-a.speed_tolerance_rpm|a.engine_speed>p.ne_map(end)+a.speed_tolerance_rpm);
% A zero-torque legacy sample has undefined speed, retained in every export.
% It cannot exceed the strictly positive endpoint-saturated upper envelope.
a.engine_limit_unknown=~a.engine_speed_valid;
for motor={'A','B'}
 key=motor{1}; if key=='A', ni=6; ti=18; else, ni=7; ti=19; end
 n=o(:,ni); torque=o(:,ti); axis=p.(['n' key '_map']);
 lower=lookup(axis,p.(['T' key '_min_map']),n);
 upper=lookup(axis,p.(['T' key '_max_map']),n);
 m=struct('speed',n,'torque',torque,'lower',lower,'upper',upper, ...
  'peak_lower',1.5*lower,'peak_upper',1.5*upper);
 m.nominal_excess=max(torque-upper,lower-torque);
 m.peak_excess=max(torque-m.peak_upper,m.peak_lower-torque);
 m.nominal_violation=m.nominal_excess>a.torque_tolerance_Nm;
 m.peak_violation=m.peak_excess>a.torque_tolerance_Nm;
 m.overspeed=n<axis(1)-a.speed_tolerance_rpm|n>axis(end)+a.speed_tolerance_rpm;
 a.(key)=m;
end
a.motor_violation=a.A.peak_violation|a.B.peak_violation|a.A.overspeed|a.B.overspeed;
a.physical_torque_violation=a.engine_violation|a.motor_violation;
end
function y=lookup(axis,values,x)
axis=double(axis(:)); values=double(values(:));
assert(numel(axis)==numel(values)&&all(diff(axis)>0)&&all(isfinite(values)), ...
 'EMS:TorqueMap','Invalid torque map.');
y=interp1(axis,values,min(axis(end),max(axis(1),x)),'linear');
y(~isfinite(x))=NaN;
end
