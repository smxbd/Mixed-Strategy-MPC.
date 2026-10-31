function inspect_stage3_projection(project,base)
addpath(fullfile(project,'ml_ems'));startup_ml_ems;s=jsondecode(fileread(fullfile(base,'round3b','status.json')));
z=load(fullfile(s.cases(1).folder,'run.mat'),'run');r=z.run;c=r.cfg;
if isfield(c.control,'guard_state'),c.control=rmfield(c.control,'guard_state');end
if isfield(c.control,'guard_cache'),c.control=rmfield(c.control,'guard_cache');end
q=r.runtime.safety_inputs;
for k=1:220
 row=q(k,:);x=row(2:20);o=row(21:40);p=row(53:56);raw=row(45:48);
 old=[];if isfield(c.control,'guard_state'),old=c.control.guard_state;end
 c=update_constraint_guard(c,row(1),x,o,p);c=update_evt1_motion(c,old);c.control.Ts=row(57);
 if isfield(c.control,'guard_cache'),c.control=rmfield(c.control,'guard_cache');end
 c=prepare_evt1_candidate_guard(c,x,o,p,raw);g=execution_guard_limits(x,o,p,c);
 if row(1)>3.58&&row(1)<4.1
  z=g.motor_prediction;[~,~,d]=constraint_residual(row(49:52),x,o,p,c);
  fprintf('t=%.2f A=%.1f active=%d pendingTe=%.2f cmdres=%.2f enginecap=%.1f bat=[%.1f %.1f] ',row(1),o(6),z.active,p(2),d.command,g.engine_upper,g.battery_lower,g.battery_upper);
  if z.active,fprintf('nommax=%.1f predres=%.1f ',max(z.nominal_rpm),max(z.A*row(49:52)'-z.b));end
  [u,found]=project_qp(raw,x,o,p,row(41:44),c,true);
  fprintf('recoveryFound=%d ',found);if found,[~,~,dd]=constraint_residual(u,x,o,p,c);tt=dd.terms;tt(12)=-Inf;fprintf('hardResidual=%g slew=%g ',max(tt),dd.terms(12));end
  fprintf('terms=');fprintf('%d,',find(d.active_terms));fprintf('\n');
 end
end
end
