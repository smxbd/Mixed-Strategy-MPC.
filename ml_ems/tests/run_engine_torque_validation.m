function run_engine_torque_validation(project,base)
% Focused engine repair validation; no model rebuild or calibration edits.
assert(~isfolder(base),'EMS:NoOverwrite','Use a fresh simulation directory.');mkdir(base);
diary(fullfile(base,'validation.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;set(groot,'DefaultFigureVisible','off');
status=struct('phase','preflight','completed',false,'units_passed',false,'cases',{{}});
write_status(base,status);
try
 cfg=continuation_config(project);cfg.controller_id=7;cfg.cycle_name='stress300';cfg=resolve_transformer_config(cfg);
 protected=jsondecode(fileread(fullfile(project,'ml_ems','repairs','reference_physics_20261025','protected_file_verification.json')));
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 policy=jsondecode(fileread(fullfile(project,'ml_ems','config','transformer_runtime_policy.json')));
 modelHash=file_sha256(fullfile(project,'ml_ems','models','EMT_ML.slx'));assert(strcmpi(modelHash,policy.model_sha256));
 status.model_sha256=modelHash;status.matlab_version=version;status.matlab_release=version('-release');
 files={'controllers/common/update_constraint_guard.m','controllers/common/execution_guard_limits.m', ...
  'controllers/common/engine_torque_guard.m','controllers/ems_runtime.m','controllers/common/project_qp.m', ...
  'controllers/common/project_to_feasible_set.m','controllers/common/executable_power_set.m', ...
  'controllers/common/constraint_residual.m','controllers/common/rollout_cost.m', ...
  'config/resolve_transformer_config.m','continuation/run_continuation_experiment.m', ...
  'continuation/compute_continuation_metrics.m','evaluation/physical_torque_audit.m', ...
  'tests/run_engine_torque_validation.m'};
 source=cell(size(files));analysis=cell(size(files));
 for k=1:numel(files)
  file=fullfile(project,'ml_ems',files{k});
  source{k}=struct('path',files{k},'sha256',file_sha256(file));
  analysis{k}=struct('path',files{k},'messages',checkcode(file,'-id'));
 end
 save(fullfile(base,'source_hashes_and_code_analyzer.mat'),'source','analysis');
 write_json(fullfile(base,'source_hashes.json'),source);
 results=runtests(fullfile(project,'ml_ems','tests','PhysicalTorqueAuditTest.m'));
 writetable(table(results),fullfile(base,'physical_audit_unit_tests.csv'));
 assert(all([results.Passed])&&~any([results.Incomplete]),'Audit unit tests failed.');
 status.audit_unit_tests_passed=sum([results.Passed]);
 status.engine_assertions=engine_checks(cfg);
 replay=recorded_replay(project,cfg);save(fullfile(base,'recorded_engine_replay.mat'),'replay');
 writetable(replay,fullfile(base,'recorded_engine_replay.csv'));
 status.units_passed=true;write_status(base,status);
 fprintf('PREFLIGHT_PASS audit=%d engine_checks=%d\n',status.audit_unit_tests_passed,status.engine_assertions);
 cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
 for name={'stress300','suburban400'}
  startup_ml_ems;c=load_cycle(name{1});cfg.stop_time=c.time(end);cfg.cycle_name=c.name;
  paired=load(fullfile(project,'figure_outputs','two_controller_reference_restored_20261025_001','data',[c.name '_Existing.mat']),'run');
  assert(isequaln(c,paired.run.cycle),'Paired baseline input differs.');cfg.reference_RMSE=paired.run.metrics.RMSE_kmh;
  status.phase=['compile_and_simulate_' c.name];write_status(base,status);
  fprintf('BEGIN_CASE %s end=%.1f seed=%d\n',c.name,c.time(end),cfg.seed);
  run=run_continuation_experiment(cfg,c,7,cfg.seed);startup_ml_ems;
  status.cases{end+1}=struct('cycle',c.name,'status',run.status,'folder',run.folder, ...
   'error',run.error,'metrics',run.metrics,'acceptance',run.acceptance);
  write_status(base,status);fprintf('END_CASE %s %s\n',c.name,run.status);
  assert(strcmp(run.status,'completed'),'EMS:CaseFailed','Preserved run failed.');
 end
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 assert(strcmpi(file_sha256(fullfile(project,'ml_ems','models','EMT_ML.slx')),modelHash));
 for k=1:numel(source),assert(strcmpi(file_sha256(fullfile(project,'ml_ems',source{k}.path)),source{k}.sha256));end
 status.protected_unchanged=true;status.source_unchanged_during_runs=true;
 status.completed=true;status.phase='completed';write_status(base,status);
 fprintf('VALIDATION_COMPLETED acceptance_not_assumed\n');
catch ME
 status.phase='failed';status.error=getReport(ME,'extended','hyperlinks','off');
 write_status(base,status);fprintf('%s\n',status.error);rethrow(ME);
end
end

function count=engine_checks(cfg)
p=cfg.p;dt=cfg.control.legacy_Ts;alpha=exp(-dt/p.Ts_e);
x=[0 .5 1 3 3000 p.ne_max p.ne_min 800 2700 0 1000 -1000 1000 -1000 0 45 -45 0 0];
o=zeros(1,20);o(3)=60;o(4)=950;o(17)=2000;o(13)=3000*2000/9549;
cfg=update_constraint_guard(cfg,0,x,o,[3000 1200 0 0]);
o(17)=alpha*2000+(1-alpha)*1200;o(13)=3001*o(17)/9549;
cfg=update_constraint_guard(cfg,dt,x,o,[3000 500 0 0]);
assert(abs(cfg.control.guard_state.engine_input_bias)<1e-8,'Delay history/ZOH inversion mismatch.');
assert(cfg.control.guard_state.pending_engine_reference==500);
assert(cfg.control.guard_state.ne_acceleration==0);
o(17)=alpha*o(17)+(1-alpha)*500;o(13)=3004*o(17)/9549;
cfg=update_constraint_guard(cfg,2*dt,x,o,[3000 400 0 0]);
assert(abs(cfg.control.guard_state.ne_acceleration-5000)<1e-6);
s=cfg.control.guard_state;s.ne=4200;s.ne_rate=100;s.ne_acceleration=0;s.te=1355;
s.engine_input_bias=0;s.pending_engine_reference=1355;s.observation_period=dt;
fixture=cfg;fixture.p.ne_map=[3000 4500];fixture.p.Te_max_map=[2800 1000];
g=engine_torque_guard(s,fixture);assert(g.transport_delay_s==dt&&g.reserve_Nm==2);
delayTorque=alpha*s.te+(1-alpha)*s.pending_engine_reference;
actual=exp(-(g.lookahead_s-dt)/p.Ts_e)*delayTorque+ ...
 (1-exp(-(g.lookahead_s-dt)/p.Ts_e))*(g.upper+s.engine_input_bias);
assert(all(actual<=g.minimum_path_limits_Nm-g.reserve_Nm+1e-8));
h=2*dt;limit=interp1(fixture.p.ne_map,fixture.p.Te_max_map,s.ne+h*s.ne_rate)-2;
noDelayCap=(limit-exp(-h/p.Ts_e)*s.te)/(1-exp(-h/p.Ts_e));
delayedActual=alpha*delayTorque+(1-alpha)*noDelayCap;
assert(delayedActual>limit,'Counterexample must fail when delay is omitted.');
s.ne_acceleration=5000;s.ne_rate=150;s.ne=3004;
g=engine_torque_guard(s,cfg);h=g.lookahead_s;
assert(max(abs(g.predicted_rpm-(3000+2500*(2*dt+h).^2)))<1e-8);
s.ne=4300;s.ne_rate=400;s.ne_acceleration=-10000;s.te=1800;s.pending_engine_reference=1700;
g=engine_torque_guard(s,cfg);
linearLimits=interp1(p.ne_map,p.Te_max_map,min(max(p.ne_map),max(min(p.ne_map),g.constant_velocity_rpm)));
assert(all(g.minimum_path_limits_Nm<=linearLimits+1e-9),'Deceleration must not erase constant-velocity risk.');
quadLimits=interp1(p.ne_map,p.Te_max_map,min(max(p.ne_map),max(min(p.ne_map),g.predicted_rpm)));
assert(all(g.minimum_path_limits_Nm<=quadLimits+1e-9));
o(17)=1000;o(13)=3000*1000/9549;cfg.control=rmfield(cfg.control,'guard_state');
cfg=update_constraint_guard(cfg,0,x,o,[3000 2500 0 0]);
o(17)=alpha*1000+(1-alpha)*2400;o(13)=3000*o(17)/9549;
cfg=update_constraint_guard(cfg,dt,x,o,[3000 500 0 0]);
assert(cfg.control.guard_state.engine_input_bias==0,'Saturation must not create negative bias authority.');
x(4)=1;cfg=update_constraint_guard(cfg,2*dt,x,o,[3000 500 0 0]);
assert(~cfg.control.guard_state.derivative_valid&&cfg.control.guard_state.ne_acceleration==0);
before=cfg.p;g=execution_guard_limits(x,o,[3000 500 0 0],cfg);
assert(isequaln(before,cfg.p)&&isfield(g,'engine_guard'));
off=cfg;off.controller_id=1;assert(~constraint_guard_enabled(off));
count=14;fprintf('ENGINE_ASSERTIONS_PASS %d\n',count);
end

function records=recorded_replay(project,cfg)
old=jsondecode(fileread(fullfile(project,'ml_ems','results','constraint_validation_20261025_001','validation_status.json')));
rows={};
for k=1:numel(old.cases)
 c=old.cases(k);saved=load(fullfile(c.folder,'run.mat'),'run');q=saved.run.trace;t=saved.run.time;
 local=cfg;local.cycle_name=c.cycle;local=resolve_transformer_config(local);
 if strcmp(c.cycle,'stress300'),windows=[277.7 278.05;299.3 300];else,windows=[179.2 179.6;279.35 279.85];end
 previous=zeros(1,4);
 for j=1:numel(t)
  x=q(j,1:19);o=q(j,20:39);local=update_constraint_guard(local,t(j),x,o,previous);
  if any(t(j)>=windows(:,1)&t(j)<=windows(:,2))
   g=engine_torque_guard(local.control.guard_state,local);
   rows(end+1,:)={c.cycle,t(j),o(17),local.control.guard_state.ne, ...
    previous(2),q(j,45),g.upper,g.pending_torque_prediction_Nm,g.pending_prediction_excess_Nm}; %#ok<AGROW>
  end
  previous=q(j,44:47);
 end
end
records=cell2table(rows,'VariableNames',{'cycle','time_s','actual_torque_Nm','synchronous_rpm', ...
 'pending_reference_Nm','recorded_issued_reference_Nm','new_cap_Nm','pending_prediction_Nm','pending_prediction_excess_Nm'});
end

function write_status(base,status)
write_json(fullfile(base,'validation_status.json'),status);
end
function write_json(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
