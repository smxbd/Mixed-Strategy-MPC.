function run_motor_speed_figure_batch(project,base,cycles)
% Fresh closed-loop paired runs; original model and controller sources frozen.
if nargin<3,cycles={'stress300','suburban400'};end
assert(~isfolder(base),'EMS:NoOverwrite','Choose a fresh output directory.');mkdir(base);
diary(fullfile(base,'full_batch.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
cfg=continuation_config(project);cfg.seed=20260906;
cfg.paths.results=fullfile(base,'runs');cfg.results_dir=cfg.paths.results;
mkdir(cfg.paths.results);mkdir(fullfile(base,'data'));
protected={'EMT.mdl','parameter.m','parameter.mat','ml_ems/models/EMT_ML.slx'};
source=dir(fullfile(project,'ml_ems','controllers','**','*.m'));
source=[source;dir(fullfile(project,'ml_ems','config','**','*.m'))];
for k=1:numel(source),protected{end+1}=fullfile(source(k).folder,source(k).name);end %#ok<AGROW>
protected{end+1}=fullfile(cfg.model_dir,'transformer_1.mat');
hashes=cell(size(protected));
for k=1:numel(protected),hashes{k}=file_sha256(absolute(project,protected{k}));end
receipt=struct('path',protected,'sha256',hashes);write(fullfile(base,'source_hashes.json'),receipt);
names={'EVT1MotorARecoveryTest.m','SpeedControlStage2Test.m','PhysicalTorqueAuditTest.m','MotorSpeedFeasibilityTest.m'};
tests=cellfun(@(n)fullfile(project,'ml_ems','tests',n),names,'UniformOutput',false);
r=runtests(tests);writetable(table(r),fullfile(base,'unit_tests.csv'));assert(all([r.Passed])&&~any([r.Incomplete]));
status=struct('completed',false,'phase','preflight','seed',cfg.seed,'cycles',{cycles},'cases',{{}});
write(fullfile(base,'batch_status.json'),status);
try
 for j=1:numel(cycles)
  startup_ml_ems;c=load_cycle(cycles{j});referenceRMSE=NaN;
  for method=[1 7]
   startup_ml_ems;local=cfg;local.cycle_name=c.name;local.controller_id=method;local.stop_time=c.time(end);
   if method==1,label='Existing';else,label='Transformer';local.reference_RMSE=referenceRMSE;end
   status.phase=['simulate_' c.name '_' label];write(fullfile(base,'batch_status.json'),status);
   fprintf('BEGIN_CASE %s %s duration=%.1f seed=%d\n',c.name,label,c.time(end),local.seed);
   run=run_continuation_experiment(local,c,method,local.seed);startup_ml_ems;
   one=struct('cycle',c.name,'controller',label,'controller_id',method,'folder',run.folder, ...
    'status',run.status,'metrics',run.metrics,'acceptance',run.acceptance,'error',run.error);
   status.cases{end+1}=one;write(fullfile(base,'batch_status.json'),status);
   assert(strcmp(run.status,'completed'),'EMS:SimulationFailed','See preserved run and log.');
   assert(numel(run.physical.time)==round(c.time(end)/.002)+1&&abs(run.physical.time(end)-c.time(end))<1e-9);
   target=fullfile(base,'data',[c.name '_' label '.mat']);assert(~isfile(target));copyfile(fullfile(run.folder,'run.mat'),target);
   if method==1,referenceRMSE=run.metrics.RMSE_kmh;end
   fprintf('END_CASE %s %s native_samples=%d A=%d B=%d ENGINE=%d FUEL=%.9f DSOC=%.9f\n', ...
    c.name,label,numel(run.physical.time),run.metrics.motorA_overspeed_samples,run.metrics.motorB_overspeed_samples, ...
    run.metrics.engine_violation_samples,run.metrics.fuel_L,run.metrics.delta_SOC_percent);
  end
 end
 for k=1:numel(protected),assert(strcmpi(hashes{k},file_sha256(absolute(project,protected{k}))));end
 status.protected_unchanged=true;status.completed=true;status.phase='simulations_completed';
 write(fullfile(base,'batch_status.json'),status);fprintf('ALL_REQUESTED_SIMULATIONS_COMPLETED cases=%d\n',numel(status.cases));
catch ME
 status.phase='failed';status.error=getReport(ME,'extended','hyperlinks','off');write(fullfile(base,'batch_status.json'),status);rethrow(ME);
end
end
function path=absolute(project,path)
if isempty(regexp(path,'^[A-Za-z]:[\\/]','once')),path=fullfile(project,path);end
end
function write(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
