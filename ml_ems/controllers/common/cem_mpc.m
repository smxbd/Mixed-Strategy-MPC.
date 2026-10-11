function [power,warm]=cem_mpc(forecast,x,o,warm,stream,cfg,execution)
if nargin<7, execution=[]; end
c=cfg.control; H=c.horizon; S=c.samples; K=c.knots;
if isempty(warm), meanU=repmat(max(0,x(1)),1,H); else, meanU=[warm(2:end) warm(end)]; end
mu=interp1(1:H,meanU,linspace(1,H,K)); sigma=ones(1,K)*150;
best=meanU; bestCost=Inf;
for it=1:c.iterations
 knots=max(0,min(cfg.p.Pe_max,mu+randn(stream,S,K).*sigma)); knots(1,:)=mu;
 sequences=interp1(linspace(1,H,K),knots',1:H,'linear')';
 % SOC compensation is part of the scored candidate, before execution
 % mapping and rollout_cost. Limits keep the adjustment slow and bounded.
 if isfield(c,'soc_bias_gain') && c.soc_bias_gain~=0
  bias=c.soc_bias_gain*(c.soc_target-o(3)/100);
  if isfield(c,'soc_bias_max'), bias=max(-c.soc_bias_max,min(c.soc_bias_max,bias)); end
  if isfield(c,'soc_bias_rate')
   base=max(0,x(1)); bias=max(-c.soc_bias_rate*c.Ts,min(c.soc_bias_rate*c.Ts,bias));
  end
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
 if isempty(execution), fitted=knots;
 else, fitted=interp1(1:H,sequences',linspace(1,H,K))'; end
 elite=fitted(idx(1:max(2,ceil(S*c.elite_fraction))),:);
 mu=.2*mu+.8*mean(elite,1); sigma=max(5,.2*sigma+.8*std(elite,0,1));
 if val(1)<bestCost, bestCost=val(1); best=sequences(idx(1),:); end
end
warm=best; power=best(1);
end
