function e=executable_power_set(x,o,previous,original,cfg)
% Exact first-command feasible intervals along the existing wheel-demand line.
% Uses the SAME torque, battery-power and slew limits as the final projection.
% This is command feasibility, not a guarantee about future measured states.
x=x(:)'; o=o(:)'; previous=previous(:)'; original=original(:)';
p=cfg.p; c=cfg.control; [M,offset]=engine_load_relation(x,cfg);
den=max(x(5),1600); demand=M(2,:)*original(3:4)';
motors=M\[9549/den  -offset;0 demand];
lo=max([x(7) x(10) x(12) x(14)],previous-c.rate*c.Ts);
teMax=min(x(9),interp1(p.ne_map,p.Te_max_map,min(4500,max(1600,x(5)))));
hi=min([x(6) teMax x(11) x(13)],previous+c.rate*c.Ts);
nr=min(hi(1),max(lo(1),original(1)));
e=struct('a',[0 9549/den motors(:,1)'], ...
 'b',[nr 0 motors(:,2)'],'intervals',zeros(0,2), ...
 'fallback',original,'fallback_flag',0,'mode',0,'previous',previous, ...
 'previous_power',previous(2)*den/9549,'engine_speed',x(5), ...
 'engine_target',nr,'power_cap',max(0,min(p.Pe_max,teMax*den/9549)), ...
 'power_rate',c.rate(2)*den/9549,'flow',o(6:7)/9549, ...
 'aux',o(9)+p.PN0+x(18),'efficiency',c.motor_efficiency);
v=min(1050,max(750,o(4)));
bmax=interp1(p.Voltage_epr,p.Pb_max,v); bmin=interp1(p.Voltage_epr,p.Pb_min,v);
if o(3)/100<=c.soc_min, bmax=min(bmax,0); end
if o(3)/100>=c.soc_max, bmin=max(bmin,0); end
if all(lo<=hi) && all(isfinite([e.a e.b]))
 for sa=[-1 1], for sb=[-1 1]
  signs=[sa sb]; el=e.flow.*c.motor_efficiency.^(-signs);
  pa=el*e.a(3:4)'; pb=el*e.b(3:4)'+e.aux;
  % a*power <= b; sign regions make the electrical-power law affine.
  A=[e.a -e.a pa -pa -signs.*e.flow.*e.a(3:4)];
  B=[hi-e.b e.b-lo bmax-pb pb-bmin signs.*e.flow.*e.b(3:4)];
  left=0; right=e.power_cap;
  for j=1:numel(A)
   if abs(A(j))<1e-12
    if B(j)<-1e-9, right=-Inf; break; end
   elseif A(j)>0, right=min(right,B(j)/A(j));
   else, left=max(left,B(j)/A(j)); end
  end
  if left<=right && isfinite(left+right)
   e.intervals(end+1,:)=[left right]; %#ok<AGROW>
  end
 end, end
end
if isempty(e.intervals)
 % The requested wheel torque itself may be unreachable this callback.
 % Make one explicit protective projection; never score unavailable power.
 [e.fallback,d]=project_to_feasible_set(original,x,o,previous,original,cfg);
 e.fallback_flag=d.fallback_flag;
 e.mode=1+double(d.projection_command_violation>c.constraint_tolerance);
end
end
