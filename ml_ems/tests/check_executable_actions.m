function check_executable_actions(traceFile)
% Replay independent physical states, with the logged safe command as the
% reference demand. Validate against the existing full constraint evaluator.
root=fileparts(fileparts(mfilename('fullpath')));
a=load(fullfile(root,'config','transformer_reference_config.mat'),'cfg');
cfg=a.cfg; cfg.controller_id=7; cfg.transformer_profile='executable_actions';
cfg=resolve_transformer_config(cfg); cfg.control.Ts=.02;
tr=readmatrix(traceFile); checked=0; protected=0; unavailable=0;
for k=2:25:size(tr,1)
 x=tr(k,2:20); o=tr(k,21:40); original=tr(k,45:48); previous=tr(k-1,45:48);
 [M,~]=engine_load_relation(x,cfg);
 cfg.control.dynamic_torque_offset=original(2)-M(1,:)*original(3:4)';
 e=executable_power_set(x,o,previous,original,cfg);
 [power,u,pb]=map_executable_power(linspace(-100,cfg.p.Pe_max+100,65),e);
 assert(all(isfinite([power u pb]),'all'),'Nonfinite mapped action.');
 [~,checkPb,d]=constraint_residual(u,x,o,previous,cfg);
 assert(max(abs(pb-checkPb))<1e-8,'Electrical-power model differs.');
 if e.mode<2
  assert(max(d.projection_command)<=cfg.control.constraint_tolerance,'Infeasible action presented as executable.');
  [safe,~]=project_to_feasible_set(u(33,:),x,o,previous,original,cfg);
  assert(max(abs(safe-u(33,:)))<1e-8,'Final projection changes feasible command.');
  checked=checked+1;
 else, unavailable=unavailable+1; end
 protected=protected+(e.mode==1);
end
assert(checked>100,'Too few replay states covered.');
% Explicit impossible bounds must be marked unavailable, never silently safe.
x(10)=x(9)+100;
e=executable_power_set(x,o,previous,original,cfg);
assert(e.mode==2 && isempty(e.intervals),'Impossible bounds not reported.');
for id=[1 6]
 c=a.cfg; c.controller_id=id;
 assert(isequaln(c,resolve_transformer_config(c)),'Baseline config changed.');
end
check_transformer_config_source;
fprintf('EXECUTABLE_ACTION_CHECKS_PASS feasible=%d protective=%d unavailable=%d\n',checked,protected,unavailable);
end
