function [u,d]=project_to_feasible_set(raw,x,o,previous,original,cfg)
raw=raw(:)'; original=original(:)'; previous=previous(:)';
if any(~isfinite(raw)), raw=original; end
if any(~isfinite(raw)), raw=zeros(1,4); end
if any(~isfinite(previous)), previous=zeros(1,4); end
[r,~,initialDetail]=constraint_residual(raw,x,o,previous,cfg);
fallback=0; fallbackSeconds=0;
if initialDetail.projection_command<=cfg.control.constraint_tolerance
 u=raw;
else
 [M,offset]=engine_load_relation(x,cfg);
 torque=M(2,:)*original(3:4)';
 % Joint search maintains the engine/motor balance, allowing demand reduction.
 te=unique([linspace(max(0,x(10)),max(0,x(9)),41) raw(2) original(2)]);
 [tt,scale]=ndgrid(te,[1 .9 .75 .5 .25 0]);
 motors=M\[tt(:)'-offset;torque*scale(:)'];
 lowerN=max(x(7),previous(1)-cfg.control.rate(1)*cfg.control.Ts);
 upperN=min(x(6),previous(1)+cfg.control.rate(1)*cfg.control.Ts);
 nr=min(upperN,max(lowerN,raw(1)));
 candidates=[repmat(nr,numel(tt),1),tt(:),motors'];
 candidates=[raw;previous;original;candidates];
 if isfield(cfg.control,'qp_projection')&&cfg.control.qp_projection
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
  u=min(upper,max(lower,u));
  fallbackSeconds=toc(fallbackTimer);
 end
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
