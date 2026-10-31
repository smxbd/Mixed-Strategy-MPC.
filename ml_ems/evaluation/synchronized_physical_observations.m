function [t,o,ne,source]=synchronized_physical_observations(run)
% Physical schema v2 appends direct ne_act to the unchanged first 20 columns.
assert(isfield(run,'physical'),'EMS:PhysicalRequired','Physical observations are required.');
t=double(run.physical.time(:)); o=double(run.physical.signals.values);
assert(size(o,1)==numel(t)&&size(o,2)>=20,'EMS:PhysicalShape','Invalid physical observations.');
assert(all(isfinite(t))&&all(diff(t)>0)&&all(isfinite(o),'all'), ...
 'EMS:PhysicalData','Nonfinite samples or non-increasing physical timestamps.');
if size(o,2)>=21
 ne=o(:,21); source='direct ne_act; physical schema v2';
else
 % The saved plant defines Pe_act=ne_act*Te_act/9549 on the same branch.
 % Do not substitute the delayed 0.02-s controller state at zero torque.
 ne=nan(size(t)); valid=abs(o(:,17))>1e-6;
 ne(valid)=9549*o(valid,13)./o(valid,17);
 source='synchronous Pe_act/Te_act; speed undefined at zero torque';
end
end
