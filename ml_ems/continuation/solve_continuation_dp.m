function plan=solve_continuation_dp(cycle,cfg)
% Offline approximate DP: SOC state, battery-power action, prescribed cycle.
dt=1; t=(0:dt:cycle.time(end))'; v=interp1(cycle.time,cycle.v_ref,t)/3.6;
grade=interp1(cycle.time,cycle.grade,t); road=interp1(cycle.time,cycle.road_resistance,t);
aux=interp1(cycle.time,cycle.aux_power,t);
traction=(cfg.p.mass*cfg.mass_scale*gradient(v,dt)+cfg.p.mass*cfg.mass_scale*9.81.*(road+sin(grade))+.5*1.225*cfg.p.Cd*cfg.p.A*v.^2).*v/1000;
demand=traction/.85+aux; sg=cfg.dp_soc_grid(:); bg=cfg.dp_power_grid(:)';
N=numel(t); V=cfg.control.weights.terminal_soc*(sg-cfg.control.soc_target).^2;
choice=zeros(numel(sg),N-1); E=cfg.p.Cb*cfg.p.Voltage0*3.6;
for k=N-1:-1:1
 next=sg-bg*dt/E; requested=demand(k)-bg; pe=max(0,min(cfg.p.Pe_max,requested));
 ne=interp1(cfg.p.Peg,cfg.p.neg,pe); te=9549*pe./max(ne,1600);
 stageCost=fuel_rate(ne,te,cfg.p)*dt;
 candidate=interp1(sg,V,next,'linear',Inf)+stageCost;
 infeasible=requested<0|requested>cfg.p.Pe_max|next<sg(1)|next>sg(end)|te>interp1(cfg.p.ne_map,cfg.p.Te_max_map,ne);
 candidate(infeasible)=Inf; [V,j]=min(candidate,[],2); choice(:,k)=j;
end
soc=cfg.initial_soc_percent/100; power=zeros(N,1); feasible=isfinite(interp1(sg,V,soc));
for k=1:N-1
 [~,s]=min(abs(sg-soc)); j=choice(s,k); power(k)=max(0,demand(k)-bg(j)); soc=soc-bg(j)*dt/E;
 if soc<sg(1)||soc>sg(end)||power(k)>cfg.p.Pe_max, feasible=false; end
end
power(end)=power(end-1);
plan=struct('time',t,'engine_power',power,'terminal_SOC',soc,'feasible_rollout',feasible, ...
 'scope','Approximate SOC-only offline DP; not a global optimum or bound for the full Simscape plant', ...
 'soc_grid',sg,'battery_power_grid',bg,'cycle',cycle.name,'initial_SOC',cfg.initial_soc_percent);
end
