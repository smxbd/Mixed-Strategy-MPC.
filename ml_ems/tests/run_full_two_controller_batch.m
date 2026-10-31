function run_full_two_controller_batch(project,base)
% Current-code, fresh-input runs: three cycles x Existing/Transformer.
assert(~isfolder(base),'EMS:NoOverwrite','Choose a fresh batch directory.');mkdir(base);
diary(fullfile(base,'full_batch.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;set(groot,'DefaultFigureVisible','off');
status=struct('phase','preflight','completed',false,'seed',20260906,'cases',{{}});
write_json(fullfile(base,'batch_status.json'),status);
try
 cfg=continuation_config(project);cfg.seed=status.seed;cfg.paths.results=fullfile(base,'runs');
 cfg.results_dir=cfg.paths.results;mkdir(cfg.paths.results);mkdir(fullfile(base,'data'));
 protected=jsondecode(fileread(fullfile(project,'ml_ems','repairs','reference_physics_20261025','protected_file_verification.json')));
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 reviewed=jsondecode(fileread(fullfile(project,'ml_ems','results','engine_torque_repair_20261025_001','round2','source_hashes.json')));
 for k=1:numel(reviewed)
  assert(strcmpi(file_sha256(fullfile(project,'ml_ems',reviewed(k).path)),reviewed(k).sha256),'Code differs from validated candidate.');
 end
 policy=jsondecode(fileread(fullfile(project,'ml_ems','config','transformer_runtime_policy.json')));
 modelHash=file_sha256(fullfile(project,'ml_ems','models','EMT_ML.slx'));assert(strcmpi(modelHash,policy.model_sha256));
 status.model_sha256=modelHash;status.matlab_release=version('-release');
 source=reviewed;source(end+1)=struct('path','tests/run_full_two_controller_batch.m', ...
  'sha256',file_sha256(fullfile(project,'ml_ems','tests','run_full_two_controller_batch.m')));
 write_json(fullfile(base,'source_hashes.json'),source);
 status.phase='running';write_json(fullfile(base,'batch_status.json'),status);
 fprintf('PREFLIGHT_PASS protected_hashes=%d frozen_model_and_weights_verified\n',numel(protected));
 for name={'city200','stress300','suburban400'}
  baselineRMSE=NaN;startup_ml_ems;c=load_cycle(name{1});
  for method=[1 7]
   startup_ml_ems;clear ems_runtime;
   local=cfg;local.cycle_name=c.name;local.controller_id=method;local.stop_time=c.time(end);
   if method==1,label='Existing';else,label='Transformer';local.reference_RMSE=baselineRMSE;end
   effective=resolve_transformer_config(local);
   if method==7&&strcmp(c.name,'city200'),assert(~constraint_guard_enabled(effective));end
   if method==7&&~strcmp(c.name,'city200'),assert(constraint_guard_enabled(effective));end
   status.phase=['simulate_' c.name '_' label];write_json(fullfile(base,'batch_status.json'),status);
   fprintf('BEGIN_CASE %s %s end=%.1f seed=%d\n',c.name,label,c.time(end),local.seed);
   run=run_continuation_experiment(local,c,method,local.seed);startup_ml_ems;
   one=struct('cycle',c.name,'controller',label,'controller_id',method,'status',run.status, ...
    'folder',run.folder,'error',run.error,'metrics',run.metrics,'acceptance',run.acceptance);
   status.cases{end+1}=one;write_json(fullfile(base,'batch_status.json'),status);
   assert(strcmp(run.status,'completed'),'EMS:CaseFailed','Preserved run failed; see logs.');
   assert(abs(run.time(end)-c.time(end))<.021&&numel(run.physical.time)==round(c.time(end)/.002)+1);
   target=fullfile(base,'data',[c.name '_' label '.mat']);assert(~isfile(target));
   copyfile(fullfile(run.folder,'run.mat'),target);
   if method==1,baselineRMSE=run.metrics.RMSE_kmh;end
   fprintf('END_CASE %s %s %s physical_samples=%d\n',c.name,label,run.status,numel(run.physical.time));
  end
 end
 for k=1:numel(protected),assert(strcmpi(file_sha256(protected(k).path),protected(k).sha256));end
 assert(strcmpi(file_sha256(fullfile(project,'ml_ems','models','EMT_ML.slx')),modelHash));
 for k=1:numel(source),assert(strcmpi(file_sha256(fullfile(project,'ml_ems',source(k).path)),source(k).sha256));end
 status.protected_unchanged=true;status.source_unchanged=true;status.completed=true;status.phase='simulations_completed';
 write_json(fullfile(base,'batch_status.json'),status);
 fprintf('SIX_SIMULATIONS_COMPLETED raw_acceptance_preserved\n');
catch ME
 status.phase='failed';status.error=getReport(ME,'extended','hyperlinks','off');
 write_json(fullfile(base,'batch_status.json'),status);fprintf('%s\n',status.error);rethrow(ME);
end
end

function write_json(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
