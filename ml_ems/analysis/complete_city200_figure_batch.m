function complete_city200_figure_batch(project,base)
% Explicitly requested city200 extension; preserve all already completed runs.
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
status=jsondecode(fileread(fullfile(base,'batch_status.json')));assert(status.completed&&numel(status.cases)==4);
assert(~any(strcmp({status.cases.cycle},'city200')));
diary(fullfile(base,'city200_batch.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
receipt=jsondecode(fileread(fullfile(base,'source_hashes.json')));
verify(project,receipt);status.completed=false;status.cycles={'stress300','suburban400','city200'};
cfg=continuation_config(project);cfg.seed=status.seed;cfg.paths.results=fullfile(base,'runs');cfg.results_dir=cfg.paths.results;
status.phase='city200_extension_preflight';write(base,status);
try
 startup_ml_ems;c=load_cycle('city200');referenceRMSE=NaN;
 for method=[1 7]
  startup_ml_ems;local=cfg;local.cycle_name=c.name;local.controller_id=method;local.stop_time=c.time(end);
  if method==1,label='Existing';else,label='Transformer';local.reference_RMSE=referenceRMSE;end
  status.phase=['simulate_city200_' label];write(base,status);
  fprintf('BEGIN_CASE city200 %s duration=200 seed=%d\n',label,local.seed);
  run=run_continuation_experiment(local,c,method,local.seed);startup_ml_ems;
  one=struct('cycle',c.name,'controller',label,'controller_id',method,'folder',run.folder, ...
   'status',run.status,'metrics',run.metrics,'acceptance',run.acceptance,'error',run.error);
  status.cases(end+1)=one;write(base,status);
  assert(strcmp(run.status,'completed'),'EMS:SimulationFailed','See preserved run.');
  assert(numel(run.physical.time)==100001&&abs(run.physical.time(end)-200)<1e-9);
  target=fullfile(base,'data',['city200_' label '.mat']);assert(~isfile(target));copyfile(fullfile(run.folder,'run.mat'),target);
  if method==1,referenceRMSE=run.metrics.RMSE_kmh;end
  fprintf('END_CASE city200 %s native_samples=%d A=%d B=%d ENGINE=%d FUEL=%.9f DSOC=%.9f\n', ...
   label,numel(run.physical.time),run.metrics.motorA_overspeed_samples,run.metrics.motorB_overspeed_samples, ...
   run.metrics.engine_violation_samples,run.metrics.fuel_L,run.metrics.delta_SOC_percent);
 end
 verify(project,receipt);status.protected_unchanged=true;status.completed=true;status.phase='simulations_completed';write(base,status);
 fprintf('SIX_FRESH_SIMULATIONS_COMPLETED\n');
catch ME
 status.phase='failed';status.error=getReport(ME,'extended','hyperlinks','off');write(base,status);rethrow(ME);
end
end
function verify(project,receipt)
for k=1:numel(receipt)
 path=receipt(k).path;if isempty(regexp(path,'^[A-Za-z]:[\\/]','once')),path=fullfile(project,path);end
 assert(strcmpi(file_sha256(path),receipt(k).sha256),'Frozen source changed.');
end
end
function write(base,value)
fid=fopen(fullfile(base,'batch_status.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
