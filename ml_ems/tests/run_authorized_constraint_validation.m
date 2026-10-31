function run_authorized_constraint_validation(project,base)
% Authorized one-pass validation. No rebuild, calibration or policy edits.
assert(~isfolder(base),'EMS:NoOverwrite','Use a new validation directory.');
mkdir(base);diary(fullfile(base,'validation.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
set(groot,'DefaultFigureVisible','off');
status=struct('phase','preflight','completed',false,'units_passed',false,'cases',{{}});
write_status(base,status);
try
 cfg=continuation_config(project);cfg.controller_id=7;cfg.cycle_name='stress300';
 cfg=resolve_transformer_config(cfg);
 assert(constraint_guard_enabled(cfg),'Repair guard not enabled.');
 protected=jsondecode(fileread(fullfile(project,'ml_ems','repairs','reference_physics_20261025','protected_file_verification.json')));
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 status.matlab_version=version;status.matlab_release=version('-release');
 records=jsondecode(fileread(fullfile(project,'ml_ems','docs','transformer_constraint_static_checks_20261025.json')));
 analysis=cell(numel(records.matlab_source_parse_results),1);
 snapshot=fullfile(base,'source_snapshot');mkdir(snapshot);
 for k=1:numel(records.matlab_source_parse_results)
  relative=records.matlab_source_parse_results(k).path;file=fullfile(project,relative);
  assert(strcmpi(file_sha256(file),records.matlab_source_parse_results(k).sha256),'Source differs from static review.');
  analysis{k}=struct('file',relative,'messages',checkcode(file,'-id'));
  dest=fullfile(snapshot,relative);if ~isfolder(fileparts(dest)),mkdir(fileparts(dest));end
  copyfile(file,dest);
 end
 save(fullfile(base,'code_analyzer.mat'),'analysis');
 results=runtests(fullfile(project,'ml_ems','tests','PhysicalTorqueAuditTest.m'));
 writetable(table(results),fullfile(base,'physical_audit_unit_tests.csv'));
 assert(all([results.Passed])&&~any([results.Incomplete]),'Existing audit unit tests failed.');
 status.audit_unit_tests_passed=sum([results.Passed]);
 status.guard_assertions=guard_checks(cfg);
 status.units_passed=true;status.phase='compile_and_simulate_stress300';
 write_status(base,status);fprintf('PREFLIGHT_PASS audit=%d guard_assertions=%d\n',status.audit_unit_tests_passed,status.guard_assertions);
 cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
 % Exactly the two requested cases, once each. Compile is performed by sim.
 for name={'stress300','suburban400'}
  startup_ml_ems;
  c=load_cycle(name{1});cfg.stop_time=c.time(end);cfg.cycle_name=c.name;
  historical=fullfile(project,'figure_outputs','two_controller_reference_restored_20261025_001','data',[c.name '_Existing.mat']);
  if isfile(historical)
   previous=load(historical,'run');cfg.reference_RMSE=previous.run.metrics.RMSE_kmh;
   assert(isequaln(c,previous.run.cycle),'Cycle differs from paired Existing input.');
  else
   error('EMS:BaselineRequired','Paired Existing raw data missing.');
  end
  status.phase=['compile_and_simulate_' c.name];write_status(base,status);
  fprintf('BEGIN_CASE %s end=%.1f seed=%d\n',c.name,c.time(end),cfg.seed);
  run=run_continuation_experiment(cfg,c,7,cfg.seed);
  startup_ml_ems;
  one=struct('cycle',c.name,'status',run.status,'folder',run.folder,'error',run.error, ...
   'metrics',run.metrics,'acceptance',run.acceptance);
  status.cases{end+1}=one;write_status(base,status);
  fprintf('END_CASE %s %s\n',c.name,run.status);
  if ~strcmp(run.status,'completed')
   status.phase='failed_case';write_status(base,status);error('EMS:CaseFailed','Case failed; see preserved outputs.');
  end
 end
 status.phase='protected_hash_verification';write_status(base,status);
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 policy=jsondecode(fileread(fullfile(project,'ml_ems','config','transformer_runtime_policy.json')));
 assert(strcmpi(file_sha256(fullfile(project,'ml_ems','models','EMT_ML.slx')),policy.model_sha256));
 status.protected_unchanged=true;status.completed=true;status.phase='completed';
 write_status(base,status);fprintf('VALIDATION_COMPLETED constraints_not_assumed_passed\n');
catch ME
 status.error=getReport(ME,'extended','hyperlinks','off');status.phase='failed';
 write_status(base,status);fprintf('%s\n',status.error);rethrow(ME);
end
end

function count=guard_checks(cfg)
cfg.control.Ts=cfg.control.legacy_Ts;cfg.control.dynamic_torque_offset=0;p=cfg.p;
x=[0 .5 1 1 3000 p.ne_max p.ne_min 800 2700 0 1000 -1000 1000 -1000 0 45 -45 0 0];
o=zeros(1,20);o(3)=60;o(4)=950;o(6)=p.a11*3000;o(9)=15;
o(13)=3000*1000/9549;o(16)=o(9)+p.PN0;o(17)=1000;
previous=[3000 0 0 0];
cfg=update_constraint_guard(cfg,0,x,o,previous);
assert(cfg.control.guard_state.synchronous_speed&&abs(cfg.control.guard_state.ne-3000)<1e-9);
g=execution_guard_limits(x,o,previous,cfg);assert(all(isfinite([g.engine_upper g.battery_lower g.battery_upper])));
[r,~,d]=constraint_residual([previous;previous],x,o,previous,cfg);
assert(numel(r)==2&&size(d.terms,2)==14&&all(d.command<=cfg.control.constraint_tolerance));
[u,found]=project_qp(previous,x,o,previous,previous,cfg);assert(found&&all(isfinite(u)));
[~,~,qd]=constraint_residual(u,x,o,previous,cfg);assert(qd.command<=cfg.control.constraint_tolerance);
e=executable_power_set(x,o,previous,previous,cfg);assert(~isempty(e.intervals));
[~,u,pb]=map_executable_power([0;10],e);assert(isequal(size(u),[2 4])&&all(isfinite(pb)));
J=rollout_cost(zeros(2,cfg.control.horizon),zeros(cfg.control.horizon,4,1),x,o,cfg,e);
assert(numel(J)==2&&all(isfinite(J)));
o2=o;o2(17)=995;o2(13)=3001*995/9549;
cfg=update_constraint_guard(cfg,.02,x,o2,previous);assert(cfg.control.guard_state.derivative_valid);
x(4)=3;cfg=update_constraint_guard(cfg,.04,x,o2,previous);assert(~cfg.control.guard_state.derivative_valid);
o2(17)=3000;o2(13)=4500*3000/9549;cfg.control=rmfield(cfg.control,'guard_state');
[~,~,d]=constraint_residual(previous,x,o2,previous,cfg);assert(d.state>=2002-1e-9);
off=cfg;off.controller_id=1;assert(~constraint_guard_enabled(off));
count=12;
fprintf('GUARD_FUNCTION_ASSERTIONS_PASS %d\n',count);
end

function write_status(base,status)
fid=fopen(fullfile(base,'validation_status.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s',jsonencode(status,'PrettyPrint',true));fclose(fid);
end
