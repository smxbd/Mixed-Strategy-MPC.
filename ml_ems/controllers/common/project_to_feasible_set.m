function [u,d]=project_to_feasible_set(raw,x,o,previous,original,cfg)
raw=raw(:)'; original=original(:)'; previous=previous(:)';
if any(~isfinite(raw)), raw=original; end
if any(~isfinite(raw)), raw=zeros(1,4); end
if any(~isfinite(previous)), previous=zeros(1,4); end
cfg=prepare_evt1_candidate_guard(cfg,x,o,previous,raw);
[r,~,initialDetail]=constraint_residual(raw,x,o,previous,cfg);
fallback=0; fallbackSeconds=0;
rawValid=initialDetail.projection_command<=cfg.control.constraint_tolerance;
if constraint_guard_enabled(cfg),rawValid=initialDetail.command<=cfg.control.constraint_tolerance;end
if rawValid
 u=raw;
else
 [M,offset]=engine_load_relation(x,cfg);
 torque=M(2,:)*original(3:4)';
 % Try a validated QP before allocating/evaluating the fallback grid.
 qpFound=false;
 if constraint_guard_enabled(cfg) && isfield(cfg.control,'qp_projection')&&cfg.control.qp_projection
  [candidate,qpFound]=project_qp(raw,x,o,previous,original,cfg);
 end
 if ~qpFound&&constraint_guard_enabled(cfg)&&x(4)==1&&strcmp(cfg.cycle_name,'stress300')
  recoveryGuard=execution_guard_limits(x,o,previous,cfg);
  if recoveryGuard.motor_prediction.active
   recoveryTimer=tic;
   [candidate,qpFound]=project_qp(raw,x,o,previous,original,cfg,true);
   if qpFound,fallback=1;fallbackSeconds=toc(recoveryTimer);end
  end
 end
 if qpFound
  u=candidate;
 else
 % Joint search maintains the engine/motor balance, allowing demand reduction.
 te=unique([linspace(max(0,x(10)),max(0,x(9)),41) raw(2) original(2)]);
 [tt,scale]=ndgrid(te,[1 .9 .75 .5 .25 0]);
 motors=M\[tt(:)'-offset;torque*scale(:)'];
 lowerN=max(x(7),previous(1)-cfg.control.rate(1)*cfg.control.Ts);
 upperN=min(x(6),previous(1)+cfg.control.rate(1)*cfg.control.Ts);
 if constraint_guard_enabled(cfg)
  guard=execution_guard_limits(x,o,previous,cfg);
  guardLower=max(lowerN,guard.speed_lower);guardUpper=min(upperN,guard.speed_upper);
  if guardLower<=guardUpper,lowerN=guardLower;upperN=guardUpper;end
 end
 nr=min(upperN,max(lowerN,raw(1)));
 candidates=[repmat(nr,numel(tt),1),tt(:),motors'];
 candidates=[raw;previous;original;candidates];
 if ~constraint_guard_enabled(cfg) && isfield(cfg.control,'qp_projection')&&cfg.control.qp_projection
  [candidate,found]=project_qp(raw,x,o,previous,original,cfg);
  if found, candidates=[candidate;candidates]; end
 end
 [res,~,candidateDetail]=constraint_residual(candidates,x,o,previous,cfg);
 distance=sum(((candidates-raw)./[1000 2000 1000 1000]).^2,2);
 if isfield(cfg.control,'reference_balance_soft') && cfg.control.reference_balance_soft
  distance=distance+10*((candidates(:,2)-candidates(:,3:4)*M(1,:)'-offset)/1000).^2;
 end
% A soft reference-balance mode may omit the balance term from the search
% residual, but the delivered action must still satisfy every physical
% constraint before it is accepted.
valid=find(candidateDetail.command<=cfg.control.constraint_tolerance);
if ~isempty(valid)
  [~,j]=min(distance(valid)); u=candidates(valid(j),:);
 else
  % Preserve the physically closest deliverable point. This explicitly
  % reduces wheel demand when the requested point is unreachable, instead of
  % replaying the original command and hiding the demand deficit.
  fallbackTimer=tic; fallback=1;
  score=candidateDetail.command + 1e-9*distance;
  [~,j]=min(score); u=candidates(j,:);
  if any(~isfinite(u)), u=zeros(1,4); end
  lower=[max(0,min(x(7),x(6))) max(0,x(10)) x(12) x(14)];
  upper=[max(0,x(6)) max(0,x(9)) x(11) x(13)];
  if constraint_guard_enabled(cfg)
   guard=execution_guard_limits(x,o,previous,cfg);
   % A recovery command is not a feasible solution when the interval is
   % empty. Retain the final residual, but do not undo its torque reduction.
   upper(2)=max(lower(2),min(upper(2),guard.engine_upper));
   if guard.motor_prediction.active&&isfield(guard.motor_prediction,'minimum_engine_reference')&& ...
    upper(2)>=guard.motor_prediction.minimum_engine_reference
    lower(2)=max(lower(2),guard.motor_prediction.minimum_engine_reference);
   end
  end
  u=min(upper,max(lower,u));
  fallbackSeconds=toc(fallbackTimer);
 end
 end % QP failed: grid recovery remains explicit and auditable.
end
[r,~,finalDetail]=constraint_residual(u,x,o,previous,cfg);
d=struct('projection_distance',norm((u-raw)./[1000 2000 1000 1000]), ...
 'command_violation',finalDetail.command,'state_violation',finalDetail.state, ...
 'projection_command_violation',finalDetail.projection_command, ...
 'fallback_flag',fallback,'fallback_seconds',fallbackSeconds,'constraint_violation',r,'hard_infeasible',double(r>cfg.control.constraint_tolerance));
% Record the reason and delivered-demand loss at the point of protection.
d.requested_action=raw; d.applied_action=u; d.demand_loss=raw(2)-u(2);
d.requested_wheel_torque=raw(2); d.delivered_wheel_torque=u(2);
d.infeasibility_reason=local_reason(finalDetail,initialDetail,fallback);
d.active_terms=finalDetail.active_terms; d.active_state=finalDetail.active_state;
if isfield(finalDetail,'guard')
 d.guard=finalDetail.guard;
 if finalDetail.guard.motor_guard.static_infeasible
  d.infeasibility_reason='static_motor_speed_interval_empty';
 elseif ~finalDetail.guard.motor_guard.mode_known
  d.infeasibility_reason='unobserved_mode_dynamics';
 elseif finalDetail.guard.bound_conflict
  d.infeasibility_reason='predictive_bounds_infeasible';
 elseif finalDetail.state>cfg.control.constraint_tolerance && finalDetail.command<=cfg.control.constraint_tolerance
  d.infeasibility_reason='measured_state_constraint';
 end
end
if isfield(cfg.control,'log_constraint_replay') && cfg.control.log_constraint_replay
 [~,offset]=engine_load_relation(x,cfg);
 d.replay=struct('x',x,'o',o,'raw',raw,'safe',u,'previous',previous, ...
  'original',original,'dt',cfg.control.Ts,'offset',offset, ...
  'terms',finalDetail.terms,'command',finalDetail.command, ...
  'projection_command',finalDetail.projection_command, ...
  'state',finalDetail.state,'fallback',fallback, ...
  'term_names',{finalDetail.term_names},'active_terms',finalDetail.active_terms, ...
  'active_state',finalDetail.active_state,'demand_loss',d.demand_loss, ...
  'reason',d.infeasibility_reason);
end
end

function reason=local_reason(finalDetail,initialDetail,fallback)
if fallback, reason='no_feasible_candidate_fallback'; return; end
if initialDetail.projection_command<=0, reason='none'; return; end
idx=find(initialDetail.active_terms,1,'first');
if ~isempty(idx), reason=['constraint_' initialDetail.term_names{idx}]; return; end
if any(initialDetail.active_state), reason='state_constraint'; return; end
if finalDetail.projection_command>0, reason='projection_residual'; else, reason='projected'; end
end
