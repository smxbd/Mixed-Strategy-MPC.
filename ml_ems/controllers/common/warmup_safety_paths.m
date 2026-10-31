function warmup_safety_paths(cfg)
% Initialization only: exercise all solver/mode/early-return branches.
% No plant state, retained controller state or random stream is advanced.
p=cfg.p;
for stage=[0 1 2 3]
 for range=[1 2]
  for road=[0 800 4000]
   x=[300 .5 range stage 3000 4200 1600 road 2400 0 1110 -1110 1110 -1110 0 45 -45 0 0];
   o=zeros(1,20);o(2)=road/((1+p.kh)/p.kh*p.ic/.377/p.rz);
   o(3)=60;o(4)=950;o(17)=1000;o(13)=3000*1000/9549;
   if stage==3,o(6:7)=[p.a21 p.a22;p.b21 p.b22]*[3000;road];
   else,o(6:7)=[p.a11 p.a12;p.b11 p.b12]*[3000;road];end
   original=[3000 1000 100 -200];local=cfg;
   local=update_constraint_guard(local,0,x,o,original);
   local=update_constraint_guard(local,.02,x,o,original);
   project_qp(original,x,o,original,original,local);
   project_to_feasible_set([4200 2400 1110 1110],x,o,original,original,local);
  end
 end
end

if strcmp(cfg.cycle_name,'stress300')
 local=cfg;x(4)=1;x(3)=1;x(8)=0;
 x(5)=(p.nA_max-20)/p.a11;x(6)=4200;x(7)=1600;
 o(2)=0;o(17)=1000;o(13)=x(5)*1000/9549;
 o(6)=p.a11*x(5);o(7)=0;original=[3800 1000 100 -200];
 for tick=0:2
  old=[];if isfield(local.control,'guard_state'),old=local.control.guard_state;end
  local=update_constraint_guard(local,tick*.02,x,o,original);
  local=update_evt1_motion(local,old);
 end
 project_to_feasible_set(original,x,o,original,original,local);
end

end
