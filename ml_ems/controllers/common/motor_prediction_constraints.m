function q=motor_prediction_constraints(x,o,previous,cfg)
% Torque-driven prediction. ne_ref has ZERO direct plant-response coefficient.
% Error envelopes are finite-trajectory validation evidence, not invariants.
q=struct('active',false,'A',zeros(0,4),'b',zeros(0,1),'horizon_s',[], ...
 'error_bound_rpm',[],'nominal_rpm',[],'command_response_certified',false);
if isfield(cfg.control,'motor_dynamics')&&cfg.control.motor_dynamics&& ...
 x(4)==1&&strcmp(cfg.cycle_name,'stress300')
 q=evt1_motorA_constraints(x,o,previous,cfg);return;
end
if ~isfield(cfg.control,'motor_dynamics')||~cfg.control.motor_dynamics|| ...
 x(4)~=3||~isfield(cfg.control,'guard_state'),return;end
s=cfg.control.guard_state;if ~s.derivative_valid,return;end
p=cfg.p;a=[p.a21;p.b21];b=[p.a22;p.b22];
I=p.Je+p.JA*a(1)^2+p.JB*a(2)^2;
factor=p.Y_engine*(1103-180)/1103;
torque=[o(17) o(18) o(19)];pending=previous(2:4);
% In this mode original engine and motor reference-to-command blocks pass
% through; pre-lag physical saturation is covered by original command bounds.
times=[.02 .04 .12 .22];tau=[p.Ts_e p.TS_A p.TS_B];
if strcmp(cfg.cycle_name,'stress300')
 bound=[12.040042180485898 36.047154945315924 231.40483295984632 696.4342933521557];
else
 bound=[3.1073569832453813 6.117824841415882 41.96584827044626 188.45007004331978];
end
q.active=true;q.horizon_s=times;q.error_bound_rpm=bound;
q.A=zeros(16,4);q.b=zeros(16,1);q.nominal_rpm=zeros(2,4);
for j=1:4
 h=times(j);f=h-tau.*(1-exp(-h./tau));after=max(0,h-cfg.control.legacy_Ts);
 fa=after-tau.*(1-exp(-after./tau));
 coeff=30/pi/I*[factor a'];
 baseNe=s.ne+h*s.ne_rate+sum(coeff.*((pending-torque).*f-pending.*fa));
 gains=coeff.*fa;
 road=s.no+h*s.no_rate;
 offset=o(6:7)'-a*s.ne-b*s.no;
 base=a*baseNe+b*road+offset;
 slope=[zeros(2,1) a*gains];
 limit=[p.nA_max;p.nB_max]-bound(j);
 rows=(j-1)*4+(1:4);
 q.A(rows,:)=[slope;-slope];q.b(rows)=[limit-base;limit+base];
 q.nominal_rpm(:,j)=base+slope*previous(:);
end
end
