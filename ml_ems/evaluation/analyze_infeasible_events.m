function report=analyze_infeasible_events(runtime,targetTimes,tol)
%ANALYZE_INFEASIBLE_EVENTS Extract per-event constraint and demand-loss audit.
% runtime is the controller runtime struct returned by ems_runtime('last_report').
if nargin<2||isempty(targetTimes), targetTimes=[6.2 6.4 90.4 90.6 184.9]; end
if nargin<3, tol=0.051; end
report=struct('time',num2cell(targetTimes(:)),'event',cell(numel(targetTimes),1));
events=[];
if isfield(runtime,'infeasibility_events'), events=runtime.infeasibility_events; end
for k=1:numel(targetTimes)
 if isempty(events), continue; end
 [d,j]=min(abs([events.time]-targetTimes(k)));
 if d<=tol, report(k).event=events(j); end
end
if nargout==0
 for k=1:numel(report)
  if isempty(report(k).event), fprintf('t=%.3f: no replay event\n',report(k).time); continue; end
  e=report(k).event;
  fprintf('t=%.3f reason=%s fallback=%d demand_loss=%.6g command=%.6g state=%.6g\n', ...
   e.time,e.infeasibility_reason,e.fallback_flag,e.demand_loss,e.command_violation,e.state_violation);
 end
end
end
