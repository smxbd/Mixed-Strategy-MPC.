function [u,trace]=ems_runtime(op,key,varargin)
persistent runs lastReport
if isempty(runs), runs=containers.Map('KeyType','double','ValueType','any'); end
u=[]; trace=[];
switch op
 case 'record_wrapper'
  state=runs(key);
  if ~isfield(state.runtime,'wrapper_times'), state.runtime.wrapper_times=zeros(0,2); end
  state.runtime.wrapper_times(end+1,:)=[varargin{1},varargin{2}]; runs(key)=state; return
 case 'last_report'
  u=lastReport; return
 case 'reset'
  initTimer=tic; lastReport=[];
  cfg=resolve_transformer_config(varargin{1}); state=struct('cfg',cfg,'last_time',-Inf,'last_safety_time',-Inf,'last_stage',NaN,'u',zeros(1,4),'trace',zeros(1,62), ...
   'history',zeros(0,8),'warm',[],'stream',RandStream('mt19937ar','Seed',cfg.seed),'nets',[]);
  % Controller 9 is self-contained: it must not load ML artifacts or enter
  % the predictor warm-up path. This keeps the reconstruction branch
  % independent of the frozen Transformer artifacts.
  if cfg.controller_id>=4 && cfg.controller_id~=5 && cfg.controller_id~=9, state.nets=load_trained_models(cfg); end
  if cfg.controller_id~=1&&cfg.controller_id~=9&&isfield(cfg.control,'warmup')&&cfg.control.warmup, warmup_controller(cfg,state.nets); end
  state.runtime=struct('initialization_s',toc(initTimer),'max_callback_s',0,'max_safety_callback_s',0,'max_decision_callback_s',0,'callback_total_s',0,'callback_count',0,'method',cfg.controller_id);
  if cfg.controller_id==7
   state.runtime.effective_control=cfg.control;
   state.runtime.config_source=cfg.transformer_config_source;
  end
  % Prewarm the shared CEM implementation during initialization so JIT and
  % first-call overhead are not charged to the first online decision.
  if cfg.controller_id==5 || cfg.controller_id==7
   x0=zeros(19,1); x0(4)=1; x0(5)=cfg.p.ne_idl; x0(6)=cfg.p.ne_max; x0(7)=cfg.p.ne_min;
   o0=zeros(20,1); o0(3)=60; forecast0=zeros(cfg.control.horizon,4,1);
   warm0=[]; [~,~]=cem_mpc(forecast0,x0,o0,warm0,state.stream,cfg);
   % Also prewarm the predictor/action/projection call path.
   dummy=state; original0=[3000 0 0 0];
   [raw0,dummy]=ems_step(0,x0,o0,original0,dummy); %#ok<ASGLU>
   [~,~]=project_to_feasible_set(raw0,x0,o0,state.u,original0,cfg);
   state.runtime.initialization_s=toc(initTimer);
  end
  runs(key)=state; return
 case 'remove'
  if isKey(runs,key), finished=runs(key); lastReport=finished.runtime; remove(runs,key); end; return
end
s=runs(key); t=varargin{1}; legacy=varargin{2}(:)'; obs=varargin{3}(:)'; original=varargin{4}(:)';
callbackTimer=tic;
if isfield(s.cfg.control,'incremental_balance')&&s.cfg.control.incremental_balance
 [balance,~]=engine_load_relation(legacy,s.cfg);
 % Algebraic residual of original requested actions; not measured dynamics.
 s.cfg.control.dynamic_torque_offset=original(2)-balance(1,:)*original(3:4)';
end
if t<=s.last_time+1e-9
 u=s.u; trace=s.trace; trace(1:39)=[legacy obs];
 if s.cfg.controller_id==1, u=original; trace(40:47)=[u u]; end
 return
end
if s.cfg.controller_id~=1 && t<s.last_time+s.cfg.control.Ts-1e-8
 trace=s.trace; trace(1:39)=[legacy obs];
 if t>s.last_safety_time+1e-9
  safetyCfg=s.cfg; safetyCfg.control.Ts=max(.002,t-s.last_safety_time);
  projectionTimer=tic;
  rawSafe=s.trace(40:43); if isfinite(s.last_stage)&&legacy(4)~=s.last_stage, rawSafe=s.u; end
  [u,dg]=project_to_feasible_set(rawSafe,legacy,obs,s.u,original,safetyCfg);
  dg.projection_seconds=toc(projectionTimer);
  trace(44:51)=[u dg.projection_distance dg.fallback_flag dg.constraint_violation dg.hard_infeasible];
  s=execution_feedback(s,t,legacy,obs,rawSafe,u,false);
  s.u=u; s.trace=trace; s.last_safety_time=t; s.last_stage=legacy(4);
  s=record_callback(s,toc(callbackTimer),false,dg,t); runs(key)=s;
 else, u=s.u; end
 return
end
timer=tic;
if s.cfg.controller_id==1
 u=original; raw=u; dg=struct('projection_distance',0,'fallback_flag',0,'constraint_violation',NaN,'hard_infeasible',0);
else
 [raw,s]=ems_step(t,legacy,obs,original,s);
 if ~isfinite(s.last_time), s.u=[min(legacy(6),max(legacy(7),raw(1))) 0 0 0]; end
 safetyCfg=s.cfg;
 if isfinite(s.last_safety_time), safetyCfg.control.Ts=max(.002,t-s.last_safety_time); end
 projectionTimer=tic;
 if isfinite(s.last_stage)&&legacy(4)~=s.last_stage && ~execution_enabled(s.cfg), raw=s.u; end
 [u,dg]=project_to_feasible_set(raw,legacy,obs,s.u,original,safetyCfg);
 dg.projection_seconds=toc(projectionTimer);
end
elapsed=toc(timer);
if s.cfg.controller_id==1, elapsed=NaN; end % Original compiled chart executes upstream; wrapper timing is not its compute time.
% 19 legacy + 20 observations + 4 raw + 4 safe + 5 diagnostics + time + 8 features + ID = 62.
feature=observation_features(legacy,obs,s.cfg);
trace=[legacy obs raw u dg.projection_distance dg.fallback_flag dg.constraint_violation dg.hard_infeasible elapsed t feature s.cfg.controller_id];
s.u=u; s.trace=trace; s.last_time=t; s.last_safety_time=t; s.last_stage=legacy(4);
s=execution_feedback(s,t,legacy,obs,raw,u,true);
s=record_callback(s,toc(callbackTimer),true,dg,t); runs(key)=s;
end
function yes=execution_enabled(cfg)
yes=cfg.controller_id==7 && isfield(cfg.control,'execution_aware') && cfg.control.execution_aware;
end
function s=execution_feedback(s,t,x,o,raw,u,isDecision)
if ~execution_enabled(s.cfg), return; end
den=max(x(5),1600); requested=raw(2)*den/9549; applied=u(2)*den/9549;
if ~isempty(s.warm)
 % Re-anchor the entire retained plan to the latest down-stream command,
 % including the four safety callbacks between optimization decisions.
 s.warm=max(0,min(s.cfg.p.Pe_max,s.warm+applied-s.warm(1)));
end
if ~isfield(s.runtime,'execution_commands'), s.runtime.execution_commands=zeros(0,14); end
% Command-equivalent power uses the action-map denominator; measured Pe is
% logged separately, never passed off as an immediately achieved command.
s.runtime.execution_commands(end+1,:)=[t isDecision requested applied o(13) x(5) raw u];
end
function s=record_callback(s,elapsed,isDecision,dg,t)
if isfield(dg,'projection_seconds')
 if ~isfield(s.runtime,'projection_times'), s.runtime.projection_times=zeros(0,3); end
 s.runtime.projection_times(end+1,:)=[t dg.projection_seconds-dg.fallback_seconds dg.fallback_seconds];
end
if ~isfield(s.runtime,'diagnostics'), s.runtime.diagnostics=zeros(0,5); end
command=NaN; state=NaN;
if isfield(dg,'command_violation'), command=dg.command_violation; state=dg.state_violation; end
s.runtime.diagnostics(end+1,:)=[t isDecision command state elapsed];
if isfield(dg,'hard_infeasible') && (dg.hard_infeasible || dg.fallback_flag)
 ev=dg; ev.time=t; ev.decision=isDecision; ev.elapsed_seconds=elapsed;
 if ~isfield(s.runtime,'infeasibility_events') || isempty(s.runtime.infeasibility_events)
  s.runtime.infeasibility_events=ev;
 else
  s.runtime.infeasibility_events(end+1)=ev;
 end
end
if isfield(dg,'replay')
 if ~isfield(s.runtime,'constraint_replay'), s.runtime.constraint_replay={}; end
 record=dg.replay; record.time=t; record.decision=isDecision;
 s.runtime.constraint_replay{end+1}=record;
end
s.runtime.max_callback_s=max(s.runtime.max_callback_s,elapsed);
if isDecision, s.runtime.max_decision_callback_s=max(s.runtime.max_decision_callback_s,elapsed);
else, s.runtime.max_safety_callback_s=max(s.runtime.max_safety_callback_s,elapsed); end
s.runtime.callback_total_s=s.runtime.callback_total_s+elapsed;
s.runtime.callback_count=s.runtime.callback_count+1;
end
