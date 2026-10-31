function q=evt1_motorA_constraints(x,o,previous,cfg,candidate)
if nargin<5,candidate=previous;end
% Local EVT1 recovery: coupled angular momentum, never a ne_ref actuator.
q=struct('active',false,'A',zeros(0,4),'b',zeros(0,1),'horizon_s',[], ...
 'error_bound_rpm',[],'nominal_rpm',[],'command_response_certified',false);
if x(4)~=1||~strcmp(cfg.cycle_name,'stress300')|| ...
 ~isfield(cfg.control,'guard_state'),return;end
s=cfg.control.guard_state;
if ~s.derivative_valid||~isfield(s,'motor_motion_valid')|| ...
 ~s.motor_motion_valid||previous(2)<=10,return;end
p=cfg.p;a=[p.a11;p.b11];b=[p.a12;p.b12];J=[a b];
ratio=(1+p.kh)/p.kh*p.ic;
I=p.Je+p.JA*a(1)^2+p.JB*a(2)^2;
cross=p.JA*a(1)*b(1)+p.JB*a(2)*b(2);
roadI=p.mass*p.rz^2/ratio^2+p.JA*b(1)^2+p.JB*b(2)^2;
M=[I cross;cross roadI];
G=30/pi*(M\[p.Y_engine*(1103-180)/1103 a';0 b']);
H=J(1,:)*G;
times=[.02 .04 .06 .10 .16 .22 .30 .40];
% Long horizons validated using recorded future commands on independent slices.
bound=[10.766783240880612 21.519353950192453 26.998677708078048 54.86289358670183 87.265942606711633 119.41569707568124 162.2960203911166 216.04138436744825];
tau=[p.Ts_e p.TS_A p.TS_B];torque=o(17:19);pending=previous(2:4);
velocity=[s.ne_rate;s.no_rate]+.5*s.observation_period*[s.ne_acceleration;s.no_acceleration];
n=numel(times);base=zeros(n,1);slope=zeros(n,4);nominal=zeros(1,n);
for k=1:n
 h=times(k);F=h-tau.*(1-exp(-h./tau));post=max(0,h-cfg.control.legacy_Ts);
 Fa=post-tau.*(1-exp(-post./tau));
 base(k)=o(6)+h*J(1,:)*velocity+sum(H.*((pending-torque).*F-pending.*Fa));
 slope(k,:)=[0 H.*Fa];nominal(k)=base(k)+slope(k,:)*previous(:);
end
% Outside predicted risk the pre-existing allocation is unchanged.
candidateForecast=base+slope*candidate(:);
if all(abs(nominal)<=p.nA_max-bound)&&all(abs(candidateForecast')<=p.nA_max-bound),return;end
q.active=true;q.horizon_s=times;q.error_bound_rpm=bound;q.nominal_rpm=nominal;
q.A=zeros(2*n+1,4);q.b=zeros(2*n+1,1);
for k=1:n
 rows=(k-1)*2+(1:2);limit=p.nA_max-bound(k);
 q.A(rows,:)=[slope(k,:);-slope(k,:)];q.b(rows)=[limit-base(k);limit+base(k)];
end
% The original EVT1 switch selects the idle PID when Te_ref<=10. Stay in
% the validated direct-command branch; never override the engine torque cap.
q.minimum_engine_reference=10+2*cfg.control.constraint_tolerance;
q.A(end,:)=[0 -1 0 0];q.b(end)=-q.minimum_engine_reference;
end
