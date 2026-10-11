function [u,info]=ecms_equivalent_step(x,o,original,cfg,previous)
% Grid ECMS: fuel g/s plus SOC-adaptive battery equivalent fuel g/s.
if nargin<5||any(~isfinite(previous)), previous=original; end
upper=max(0,x(9)*max(x(5),1600)/9549);
grid=unique([linspace(0,upper,61),max(0,original(2)*max(x(5),1600)/9549)]);
actions=zeros(numel(grid),4);
for k=1:numel(grid), actions(k,:)=action_from_power(grid(k),x,o,original,cfg); end
[~,pb,detail]=constraint_residual(actions,x,o,previous,cfg);
factor=max(0,cfg.control.ecms_factor+cfg.control.ecms_soc_gain*(cfg.control.soc_target-o(3)/100));
fuel=fuel_rate(x(5)+zeros(size(pb)),actions(:,2),cfg.p);
cost=fuel+factor*pb/cfg.LHV_kJ_kg*1000;
valid=detail.command<=cfg.control.constraint_tolerance & isfinite(cost);
if any(valid)
 cost(~valid)=Inf; [best,j]=min(cost); u=actions(j,:); found=true;
else
 u=original; best=NaN; found=false; % Shared safety projection checks this fallback.
end
info=struct('equivalent_factor',factor,'cost_g_s',best,'grid_feasible',found, ...
 'scope','Causal finite-grid equivalent-consumption minimization; shared projection follows; current-state excursions retained separately.');
end
