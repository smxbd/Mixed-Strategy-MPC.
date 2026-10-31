function run_stage3_validation(project,base)
assert(~isfolder(base));mkdir(base);diary(fullfile(base,'validation.log'));
cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
names={'EVT1MotorARecoveryTest.m','SpeedControlStage2Test.m','PhysicalTorqueAuditTest.m','MotorSpeedFeasibilityTest.m'};
files=cellfun(@(n)fullfile(project,'ml_ems','tests',n),names,'UniformOutput',false);
r=runtests(files);writetable(table(r),fullfile(base,'unit_tests.csv'));
assert(all([r.Passed])&&~any([r.Incomplete]));
cfg=continuation_config(project);cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
protected={'EMT.mdl','parameter.m','parameter.mat','ml_ems/models/EMT_ML.slx', ...
 'ml_ems/controllers/common/engine_torque_guard.m','ml_ems/controllers/common/update_constraint_guard.m'};
hashes=cell(size(protected));for k=1:numel(protected),hashes{k}=file_sha256(fullfile(project,protected{k}));end
save(fullfile(base,'protected_hashes.mat'),'protected','hashes');
status=struct('completed',false,'phase','preflight','cases',{{}});write(base,status);
for name={'stress300','suburban400'}
 startup_ml_ems;c=load_cycle(name{1});cfg.cycle_name=c.name;cfg.stop_time=c.time(end);
 fprintf('BEGIN_FULL %s duration=%.1f seed=%d\n',c.name,c.time(end),cfg.seed);
 status.phase=['simulate_' c.name];write(base,status);
 run=run_continuation_experiment(cfg,c,7,20260906);startup_ml_ems;
 status.cases{end+1}=struct('cycle',c.name,'folder',run.folder,'status',run.status, ...
  'metrics',run.metrics,'error',run.error);write(base,status);
 fprintf('END_FULL %s %s\n',c.name,run.status);assert(strcmp(run.status,'completed'),run.error);
 m=run.metrics;
 fprintf('MOTOR A=%d B=%d ENGINE=%d SAFETY_MS=%.6f FUEL=%.9f DSOC=%.9f\n', ...
  m.motorA_overspeed_samples,m.motorB_overspeed_samples,m.engine_violation_samples,m.max_safety_wrapper_s*1000,m.fuel_L,m.delta_SOC_percent);
 if strcmp(c.name,'stress300')
  assert(m.motorA_overspeed_samples==0&&m.motorB_overspeed_samples==0, ...
   'Stress motor-speed gate failed; preserve this round before further changes.');
  assert(m.engine_violation_samples==0,'Original engine protection failed.');
 end
end
for k=1:numel(protected),assert(strcmpi(hashes{k},file_sha256(fullfile(project,protected{k}))));end
status.protected_unchanged=true;status.completed=true;status.phase='completed';write(base,status);
end
function write(base,status)
fid=fopen(fullfile(base,'status.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(status,'PrettyPrint',true));fclose(fid);
end
