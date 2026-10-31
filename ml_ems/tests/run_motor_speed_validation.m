function run_motor_speed_validation(project,base)
% New full simulations, frozen model/tables/weights; no source backups.
assert(~isfolder(base),'Use a fresh output directory.');mkdir(base);
diary(fullfile(base,'validation.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
status=struct('completed',false,'phase','preflight','cases',{{}});
writejson(fullfile(base,'validation_status.json'),status);
try
 results=runtests({fullfile(project,'ml_ems','tests','PhysicalTorqueAuditTest.m'), ...
  fullfile(project,'ml_ems','tests','MotorSpeedFeasibilityTest.m')});
 writetable(table(results),fullfile(base,'unit_tests.csv'));
 assert(all([results.Passed])&&~any([results.Incomplete]));
 cfg=continuation_config(project);
 files={'EMT.mdl','parameter.m','parameter.mat','ml_ems/models/EMT_ML.slx', ...
  'ml_ems/controllers/common/engine_torque_guard.m', ...
  'ml_ems/controllers/common/update_constraint_guard.m', ...
  'ml_ems/config/transformer_reference_config.mat','ml_ems/config/transformer_runtime_policy.json', ...
  'ml_ems/controllers/common/execution_guard_limits.m', ...
  'ml_ems/controllers/common/project_to_feasible_set.m', ...
  'ml_ems/controllers/common/motor_speed_feasibility.m'};
 hashes=cell(size(files));for k=1:numel(files),hashes{k}=file_sha256(fullfile(project,files{k}));end
 weights=file_sha256(fullfile(cfg.model_dir,'transformer_1.mat'));
 analysis=cell(1,3);names={'motor_speed_feasibility','execution_guard_limits','project_to_feasible_set'};
 for k=1:3,analysis{k}=checkcode(which(names{k}),'-id');end
 save(fullfile(base,'code_analysis_and_hashes.mat'),'files','hashes','analysis','names','weights');
 cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
 for name={'stress300','suburban400'}
  startup_ml_ems;c=load_cycle(name{1});cfg.cycle_name=c.name;cfg.stop_time=c.time(end);
  paired=load(fullfile(project,'figure_outputs','two_controller_full_20261026_001','data',[c.name '_Existing.mat']),'run');
  assert(isequaln(c,paired.run.cycle));cfg.reference_RMSE=paired.run.metrics.RMSE_kmh;
  status.phase=['simulate_' c.name];writejson(fullfile(base,'validation_status.json'),status);
  fprintf('BEGIN_FRESH_CASE %s end=%.1f seed=%d\n',c.name,c.time(end),cfg.seed);
  run=run_continuation_experiment(cfg,c,7,cfg.seed);startup_ml_ems;
  status.cases{end+1}=struct('cycle',c.name,'folder',run.folder,'status',run.status, ...
   'metrics',run.metrics,'acceptance',run.acceptance,'error',run.error);
  writejson(fullfile(base,'validation_status.json'),status);
  fprintf('END_FRESH_CASE %s status=%s\n',c.name,run.status);
  assert(strcmp(run.status,'completed'),'Full simulation failed; preserve actual outputs.');
 end
 for k=1:numel(files),assert(strcmpi(hashes{k},file_sha256(fullfile(project,files{k}))));end
 assert(strcmpi(weights,file_sha256(fullfile(cfg.model_dir,'transformer_1.mat'))));
 status.completed=true;status.phase='completed';status.protected_and_source_unchanged=true;
 writejson(fullfile(base,'validation_status.json'),status);
 fprintf('FRESH_SIMULATIONS_COMPLETED; acceptance is reported independently.\n');
catch ME
 status.phase='failed';status.error=getReport(ME,'extended','hyperlinks','off');
 writejson(fullfile(base,'validation_status.json'),status);rethrow(ME);
end
end
function writejson(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
