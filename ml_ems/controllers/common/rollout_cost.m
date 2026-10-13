function J=rollout_cost(P,forecast,x,o,cfg,execution)
if nargin<6, execution=[]; end
% Vectorized causal reduced-order rollout. Hard constraints are also rechecked on the actual action.
c=cfg.control; dt=c.Ts; count=size(P,1); scenarios=size(forecast,3); allCost=zeros(count,scenarios);
for scenario=1:scenarios
 soc=repmat(o(3)/100,count,1); speed=repmat(o(2)/3.6,count,1); ne=repmat(x(5),count,1);
 previousPower=repmat(max(0,x(1)),count,1); cost=zeros(count,1); previousMode=repmat(x(4),count,1);
 if ~isempty(execution), previousPower(:)=execution.previous_power; end
 for h=1:size(P,2)
  f=forecast(h,:,scenario); [pb,~]=demand_power_balance(f,P(:,h),0,cfg.p.PN0);
  if ~isempty(execution) && h==1
   [~,~,pb]=map_executable_power(P(:,h),execution);
  end
  ocv=interp1(cfg.p.SOC_map/100,cfg.p.Uoc_map,min(.8,max(.3,soc)));
  R=interp1(cfg.p.SOC_map/100,cfg.p.R_map,min(.8,max(.3,soc)));
  disc=ocv.^2-4*R.*pb*1000; current=(ocv-sqrt(max(0,disc)))./(2*R); voltage=ocv-R.*current;
  % Use the same voltage-dependent battery power envelope as execution.
  pbmax=interp1(cfg.p.Voltage_epr,cfg.p.Pb_max,min(1050,max(750,voltage)));
  pbmin=interp1(cfg.p.Voltage_epr,cfg.p.Pb_min,min(1050,max(750,voltage)));
  pb_limited=min(pbmax,max(pbmin,pb));
  if any(pb_limited~=pb)
   pb=pb_limited;
   disc=ocv.^2-4*R.*pb*1000;
   current=(ocv-sqrt(max(0,disc)))./(2*R); voltage=ocv-R.*current;
  end
  soc=soc-current*dt/(cfg.p.Cb*3600);
  if isempty(execution)
   targetN=interp1(cfg.p.Peg,cfg.p.neg,min(1200,max(0,P(:,h)))); ne=ne+(targetN-ne)*min(1,dt/.5);
  elseif h>1
   % Actual command retains the existing regulator's speed target.
   ne=ne+(execution.engine_target-ne)*min(1,dt/.5);
  end
  te=P(:,h)*9549./max(ne,1600); maxte=interp1(cfg.p.ne_map,cfg.p.Te_max_map,min(4500,max(1600,ne)));
  torqueViolation=max(0,te-maxte); no=speed*3.6*(1+cfg.p.kh)/cfg.p.kh*cfg.p.ic/.377/cfg.p.rz;
  mode=ones(count,1); mode(speed*3.6>cfg.p.V_Shift12)=3;
  na=cfg.p.a11*ne+cfg.p.a12*no; nb=cfg.p.b12*no;
  mask=mode==3; na(mask)=cfg.p.a21*ne(mask)+cfg.p.a22*no(mask); nb(mask)=cfg.p.b21*ne(mask)+cfg.p.b22*no(mask);
  force=cfg.p.mass*cfg.mass_scale*9.81*(f(4)+sin(o(11)))+.5*1.225*cfg.p.Cd*cfg.p.A.*speed.^2;
  [~,available]=demand_power_balance(f,P(:,h),pb,cfg.p.PN0);
  acceleration=(available*1000./max(speed,3)-force)/(cfg.p.mass*cfg.mass_scale);
  speed=max(0,speed+dt*max(-5,min(3,acceleration)));
  fuel=fuel_rate(ne,te,cfg.p); if c.no_fuel_map, fuel=P(:,h)*230/3600; end
  violation=max(0,pb-pbmax).^2+max(0,pbmin-pb).^2+torqueViolation.^2/1e4+ ...
   1e4*(max(0,c.soc_min-soc).^2+max(0,soc-c.soc_max).^2)+ ...
   max(0,c.voltage_min-voltage).^2/1e4+max(0,voltage-c.voltage_max).^2/1e4+ ...
   max(0,abs(current)-c.current_max).^2/1e3+max(0,-disc)/1e5+ ...
   (max(0,abs(na)-cfg.p.nA_max).^2+max(0,abs(nb)-cfg.p.nB_max).^2)/1e6;
  batteryEquivalent=battery_equivalent_fuel_rate(pb,soc,cfg);
  cost=cost+dt*(c.weights.fuel*fuel+c.weights.battery*batteryEquivalent+ ...
   c.weights.speed*(f(1)-speed*3.6).^2+c.weights.slew*((P(:,h)-previousPower)/100).^2+ ...
   c.weights.constraint*violation)+c.weights.engine_start*(P(:,h)>5 & previousPower<=5)+c.weights.mode_switch*(mode~=previousMode);
  previousPower=P(:,h); previousMode=mode;
 end
 if ~c.no_terminal_soc, cost=cost+c.weights.terminal_soc*(soc-c.soc_target).^2; end
 allCost(:,scenario)=cost;
end
J=mean(allCost,2);
if cfg.controller_id==8 && ~c.no_uncertainty, J=J+c.weights.risk*std(allCost,0,2); end
end
