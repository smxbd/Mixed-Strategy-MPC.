function [power,warm]=cem_mpc(forecast,x,o,warm,stream,cfg,execution)
if nargin<7, execution=[]; end
c=cfg.control; H=c.horizon; S=c.samples; K=c.knots;
if isempty(warm), meanU=repmat(max(0,x(1)),1,H); else, meanU=[warm(2:end) warm(end)]; end
mu=interp1(1:H,meanU,linspace(1,H,K)); sigma=ones(1,K)*150;
% Scale exploration to the currently executable engine-power interval. A
% fixed 150 kW spread wastes samples when rate and torque limits are tight.
den=max(x(5),1600);
lo=max(0,x(10))*den/9549;
hi=max(lo,min(cfg.p.Pe_max,max(0,x(9))*den/9549));
if ~isempty(execution)
 lo=max(0,execution.previous_power-execution.power_rate*c.Ts);
 hi=min(execution.power_cap,execution.previous_power+execution.power_rate*c.Ts);
end
sigma0=max(5,0.35*max(hi-lo,eps));
sigma=min(150,ones(1,K)*sigma0);
best=meanU; bestCost=Inf;
appliedBias=0;
for it=1:c.iterations
 knots=max(0,min(cfg.p.Pe_max,mu+randn(stream,S,K).*sigma)); knots(1,:)=mu;
 sequences=interp1(linspace(1,H,K),knots',1:H,'linear')';
 % SOC compensation is part of the scored candidate, before execution
 % mapping and rollout_cost. Limits keep the adjustment slow and bounded.
 if isfield(c,'soc_bias_gain') && c.soc_bias_gain~=0
  bias=c.soc_bias_gain*(c.soc_target-o(3)/100);
  if isfield(c,'soc_bias_max'), bias=max(-c.soc_bias_max,min(c.soc_bias_max,bias)); end
  if isfield(c,'soc_bias_rate')
   % Rate-limit the correction itself; do not integrate it through warm start.
   bias=max(-c.soc_bias_rate*c.Ts,min(c.soc_bias_rate*c.Ts,bias));
  end
  appliedBias=bias;
  sequences=sequences+bias;
  sequences=max(0,min(cfg.p.Pe_max,sequences));
 end
 if ~isempty(execution)
  sequences(:,1)=map_executable_power(sequences(:,1),execution);
  for h=2:H
   step=execution.power_rate*c.Ts;
   sequences(:,h)=min(execution.power_cap,max(0, ...
    min(sequences(:,h-1)+step,max(sequences(:,h-1)-step,sequences(:,h)))));
  end
 end
 costs=rollout_cost(sequences,forecast,x,o,cfg,execution);
 [val,idx]=sort(costs);
 % Fit elites in the same (projected and bias-adjusted) space that was scored.
 fitted=interp1(1:H,sequences',linspace(1,H,K))';
 elite=fitted(idx(1:max(2,ceil(S*c.elite_fraction))),:);
 mu=.2*mu+.8*mean(elite,1); sigma=max(5,.2*sigma+.8*std(elite,0,1));
 if val(1)<bestCost, bestCost=val(1); best=sequences(idx(1),:); end
end
% Keep warm start in the un-biased coordinate system. Otherwise the next
% call would apply the same SOC correction repeatedly as an integrator.
warm=max(0,min(cfg.p.Pe_max,best-appliedBias));
power=best(1);
end
