function [u,s]=ems_step(t,x,o,original,s)
f=observation_features(x,o,s.cfg); s.history=[s.history;f];
if size(s.history,1)>s.cfg.control.history, s.history=s.history(end-s.cfg.control.history+1:end,:); end
switch s.cfg.controller_id
 case 2, error('EMS:RemovedController','DP controller removed from this branch.');
 case 3, error('EMS:RemovedController','ECMS controller removed from this branch.');
 case 4
  a=s.nets{1}; z=(f-a.muX)./a.sigmaX;
  p=predict(a.net,z); p=double(p.*a.sigmaY+a.muY); u=action_from_power(p(1),x,o,original,s.cfg);
 otherwise
  forecastTimer=tic;
  forecast=predict_demand(s.history,s.cfg,s.nets);
  forecastSeconds=toc(forecastTimer); cemTimer=tic;
  execution=[];
  if s.cfg.controller_id==7 && isfield(s.cfg.control,'execution_aware') && s.cfg.control.execution_aware
   actionCfg=s.cfg;
   if isfinite(s.last_safety_time), actionCfg.control.Ts=max(.002,t-s.last_safety_time); end
   previous=s.u;
   if ~isfinite(s.last_time)
    previous=[min(x(6),max(x(7),original(1))) 0 0 0];
   end
   execution=executable_power_set(x,o,previous,original,actionCfg);
  end
  [power,s.warm]=cem_mpc(forecast,x,o,s.warm,s.stream,s.cfg,execution);
  cemSeconds=toc(cemTimer); actionTimer=tic;
  if isempty(execution)
   u=action_from_power(power,x,o,original,s.cfg);
  else
   [power,u,pb]=map_executable_power(power,execution);
   s.warm(1)=power;
   if ~isfield(s.runtime,'execution_plan'), s.runtime.execution_plan=zeros(0,5); end
   s.runtime.execution_plan(end+1,:)=[t power pb execution.mode execution.fallback_flag];
  end
  actionSeconds=toc(actionTimer);
  if ~isfield(s.runtime,'module_times'), s.runtime.module_times=zeros(0,4); s.runtime.forecasts={}; end
  s.runtime.module_times(end+1,:)=[t forecastSeconds cemSeconds actionSeconds];
  s.runtime.forecasts{end+1}=forecast;
end
end
