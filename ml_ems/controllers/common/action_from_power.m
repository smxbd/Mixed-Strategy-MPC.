function u=action_from_power(engine_kW,x,o,original,cfg)
[M,offset]=engine_load_relation(x,cfg); demand=M(2,:)*original(3:4)';
ne=interp1(cfg.p.Peg,cfg.p.neg,min(1200,max(0,engine_kW)),'linear');
ne=min(x(6),max(max(x(7),cfg.p.ne_idl),ne)); te=9549*max(0,engine_kW)/max(x(5),1600);
motor=M\[te-offset;demand]; u=[ne te motor'];
if isfield(cfg.control,'incremental_balance')&&cfg.control.incremental_balance
 u(1)=original(1); % Keep the existing speed regulator in this diagnostic variant.
end
end
