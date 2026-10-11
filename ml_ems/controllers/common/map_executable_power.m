function [power,u,pb]=map_executable_power(request,e)
% Vectorized nearest point in a union of feasible power intervals.
request=request(:); power=request; distance=inf(size(request));
if isempty(e.intervals)
 u=repmat(e.fallback,numel(request),1);
 power=u(:,2)*max(e.engine_speed,1600)/9549;
else
 for k=1:size(e.intervals,1)
  candidate=min(e.intervals(k,2),max(e.intervals(k,1),request));
  take=abs(candidate-request)<distance;
  power(take)=candidate(take); distance(take)=abs(candidate(take)-request(take));
 end
 u=power.*e.a+e.b;
end
motor=u(:,3:4).*e.flow;
pb=sum(motor.*e.efficiency.^sign(-motor),2)+e.aux;
end
