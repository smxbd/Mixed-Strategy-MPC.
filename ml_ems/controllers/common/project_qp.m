function [best,found,audit]=project_qp(raw,x,o,previous,original,cfg)
% Enumerate four motor-power sign regions; each has affine battery constraints.
p=cfg.p; c=cfg.control; [M,offset]=engine_load_relation(x,cfg);
scale=[1000 2000 1000 1000]; target=raw./scale;
lo=max([x(7) x(10) x(12) x(14)],previous-c.rate*c.Ts);
hi=min([x(6) min(x(9),interp1(p.ne_map,p.Te_max_map,min(4500,max(1600,x(5))))) x(11) x(13)],previous+c.rate*c.Ts);
best=raw; found=false; bestCost=Inf;
audit=[];
if nargout>2
 audit=struct('lower',lo,'upper',hi,'bound_conflict',any(lo>hi), ...
  'scale',scale,'M',M,'offset',offset,'regions',{{}}, ...
  'reference_balance_soft',isfield(c,'reference_balance_soft') && c.reference_balance_soft);
end
if any(lo>hi), return; end
v=min(1050,max(750,o(4))); bmax=interp1(p.Voltage_epr,p.Pb_max,v); bmin=interp1(p.Voltage_epr,p.Pb_min,v);
if o(3)/100<=c.soc_min, bmax=min(bmax,0); end
if o(3)/100>=c.soc_max, bmin=max(bmin,0); end
aux=o(9)+p.PN0+x(18); balance=[0 1 -M(1,:)]; output=[0 0 M(2,:)]; demand=output*original';
% Penalize wheel-demand departure while allowing protective demand reduction.
q=output.*scale/1000; H=2*(eye(4)+10*(q'*q)); f=-2*(target'+10*q'*demand/1000);
soft=isfield(c,'reference_balance_soft') && c.reference_balance_soft;
if soft
 % The captured reference residual is not a measured inertia/drag term.
 qBalance=balance.*scale/1000;
 H=H+20*(qBalance'*qBalance); f=f-20*qBalance'*offset/1000;
end
persistent options
if isempty(options), options=optimoptions('quadprog','Display','off','Algorithm','active-set','ConstraintTolerance',1e-9,'OptimalityTolerance',1e-9); end
for sa=[-1 1], for sb=[-1 1]
 signs=[sa sb]; flow=o(6:7)/9549; electrical=flow.*c.motor_efficiency.^(-signs);
 A=[balance;-balance;0 0 electrical;0 0 -electrical;0 0 -sa*flow(1) 0;0 0 0 -sb*flow(2)];
 b=[offset+c.torque_balance_tolerance;-offset+c.torque_balance_tolerance;bmax-aux;aux-bmin;0;0];
 if soft, A=A(3:end,:); b=b(3:end); end
 initial=min(hi,max(lo,raw))./scale;
 [z,~,flag]=quadprog(H,f,A.*scale,b,[],[],lo./scale,hi./scale,initial,options);
 if nargout>2
  entry=struct('signs',signs,'A',A,'b',b,'exitflag',flag, ...
   'command_residual',NaN,'projection_command_residual',NaN);
  if ~isempty(z)&&all(isfinite(z))
   [~,~,check]=constraint_residual(z'.*scale,x,o,previous,cfg);
   entry.command_residual=check.command;
   entry.projection_command_residual=check.projection_command;
  end
  audit.regions{end+1}=entry;
 end
 if flag<=0||isempty(z), continue; end
 u=z'.*scale; [~,~,d]=constraint_residual(u,x,o,previous,cfg);
 % Do not accept a QP point that only satisfies the relaxed projection
 % residual; torque balance remains a hard physical constraint.
 if d.command>c.constraint_tolerance, continue; end
 cost=sum((z'-target).^2)+10*((output*u'-demand)/1000)^2;
 if soft, cost=cost+10*((balance*u'-offset)/1000)^2; end
 if cost<bestCost, best=u; found=true; bestCost=cost; end
end, end
end
