function export_stage3_replay(project,base)
addpath(fullfile(project,'ml_ems'));startup_ml_ems;diary(fullfile(base,'postflight.log'));
cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
s=jsondecode(fileread(fullfile(base,'round4','status.json')));assert(s.completed);
files={'controllers/common/evt1_motorA_constraints.m','controllers/common/update_evt1_motion.m', ...
 'controllers/common/motor_prediction_constraints.m','controllers/common/prepare_evt1_candidate_guard.m','controllers/common/constraint_residual.m', ...
 'controllers/common/project_to_feasible_set.m','controllers/common/project_qp.m','controllers/ems_runtime.m', ...
 'controllers/common/warmup_safety_paths.m','tests/EVT1MotorARecoveryTest.m'};
for k=1:numel(files)
 issues=checkcode(fullfile(project,'ml_ems',files{k}),'-id');
 fprintf('CHECKCODE %s issues=%d\n',files{k},numel(issues));
 for j=1:numel(issues),fprintf('%d %s %s\n',issues(j).line,issues(j).id,issues(j).message);end
end
for k=1:numel(s.cases)
 saved=load(fullfile(s.cases(k).folder,'run.mat'),'run');run=saved.run;cfg=run.cfg;
 if isfield(cfg.control,'guard_state'),cfg.control=rmfield(cfg.control,'guard_state');end
 if isfield(cfg.control,'guard_cache'),cfg.control=rmfield(cfg.control,'guard_cache');end
 input=run.runtime.safety_inputs;rows=zeros(size(input,1),9);
 for j=1:size(input,1)
  z=input(j,:);x=z(2:20);o=z(21:40);previous=z(53:56);
  old=[];if isfield(cfg.control,'guard_state'),old=cfg.control.guard_state;end
  cfg=update_constraint_guard(cfg,z(1),x,o,previous);cfg=update_evt1_motion(cfg,old);cfg.control.Ts=z(57);
  q=evt1_motorA_constraints(x,o,previous,cfg,z(45:48));rows(j,1:4)=[z(1),x(4),o(6),q.active];
  rows(j,5:9)=[NaN NaN NaN NaN previous(2)];
  if q.active
   rows(j,5:8)=[max(q.nominal_rpm),max(q.A*z(49:52)'-q.b),min(q.error_bound_rpm),max(q.error_bound_rpm)];
  end
 end
 tab=array2table(rows,'VariableNames',{'time_s','stage','native_observed_A_rpm','recovery_active', ...
 'max_pending_hold_forecast_rpm','applied_prediction_residual','minimum_error_bound_rpm','maximum_error_bound_rpm','pending_Te_Nm'});
 writetable(tab,fullfile(base,[s.cases(k).cycle '_recovery_callbacks.csv']));
 events=reconstruct_safety_events(run);save(fullfile(base,[s.cases(k).cycle '_offline_events.mat']),'events','-v7.3');
 dt=run.runtime.diagnostics;err=zeros(numel(events),2);
 for j=1:numel(events)
  idx=find(abs(dt(:,1)-events(j).time)<1e-9,1);err(j,:)=[events(j).command_violation-dt(idx,3),events(j).state_violation-dt(idx,4)];
 end
 fprintf('OFFLINE_REPLAY %s active=%d event_count=%d max_residual_difference=%g\n',s.cases(k).cycle,sum(rows(:,4)),numel(events),max(abs(err(:))));
 assert(all(abs(err(:))<1e-7));
end
fprintf('POSTFLIGHT_COMPLETE\n');
end
