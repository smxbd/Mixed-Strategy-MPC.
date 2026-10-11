function warmup_controller(cfg,nets)
% Offline initialization only. Throw away all synthetic histories and RNG state.
for k=1:numel(nets)
 a=nets{k};
 if cfg.controller_id==4, predict(a.net,zeros(1,8));
 else, predict(a.net,{zeros(8,cfg.control.history)},'MiniBatchSize',1); end
end
x=[300 .5 1 1 3200 4200 1600 800 2000 0 1000 -1000 1000 -1000 0 45 -45 0 0];
o=[30 30 60 950 0 1848 2664 1 15 .045 0 0 300 0 0 0 1000 -600 600 0];
original=existing_grid_ems(x);
if isfield(cfg.control,'incremental_balance')&&cfg.control.incremental_balance
 [M,~]=engine_load_relation(x,cfg); cfg.control.dynamic_torque_offset=original(2)-M(1,:)*original(3:4)';
end
s=struct('cfg',cfg,'history',zeros(0,8),'warm',[],'nets',{nets},'stream',RandStream('mt19937ar','Seed',98765),'u',original);
% The warm-up path calls ems_step before ems_runtime has attached its
% diagnostics state.  Provide the same minimal runtime container so the
% callback bookkeeping is valid during predictor prewarming.
s.runtime=struct('initialization_s',0,'max_callback_s',0,'max_safety_callback_s',0, ...
 'max_decision_callback_s',0,'callback_total_s',0,'callback_count',0,'method',cfg.controller_id);
if cfg.controller_id==2, return; end % DP requires the actual cycle plan.
for k=1:3
 [raw,s]=ems_step(0,x,o,original,s);
 project_to_feasible_set(raw,x,o,original,original,cfg);
end
end
