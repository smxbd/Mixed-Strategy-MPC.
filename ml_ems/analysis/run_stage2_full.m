function run_stage2_full(project,base,localBase)
% Full regression only after local speed/execution verification has passed.
local=jsondecode(fileread(fullfile(localBase,'status.json')));
assert(local.completed&&numel(local.cases)==2,'Local validation must finish first.');
for k=1:2
 m=local.cases(k).metrics;
 assert(m.motorA_overspeed_samples==0&&m.motorB_overspeed_samples==0, ...
  'Local motor-speed gate failed. Do not run full regression.');
 assert(m.engine_violation_samples==0,'Local engine-protection gate failed.');
end
assert(~isfolder(base));mkdir(base);diary(fullfile(base,'full_validation.log'));
cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
cfg=continuation_config(project);cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
status=struct('completed',false,'phase','start','cases',{{}}, ...
 'note','Local motor/engine tests passed; retained current failures mean overall acceptance is not presumed.');
write(base,status);
for name={'stress300','suburban400'}
 startup_ml_ems;c=load_cycle(name{1});cfg.cycle_name=c.name;cfg.stop_time=c.time(end);
 paired=load(fullfile(project,'figure_outputs','two_controller_full_20261026_001','data',[c.name '_Existing.mat']),'run');
 assert(isequaln(c,paired.run.cycle));cfg.reference_RMSE=paired.run.metrics.RMSE_kmh;
 status.phase=['full_' c.name];write(base,status);
 fprintf('BEGIN_FULL %s end=%.1f seed=%d\n',c.name,c.time(end),cfg.seed);
 run=run_continuation_experiment(cfg,c,7,cfg.seed);startup_ml_ems;
 status.cases{end+1}=struct('cycle',c.name,'folder',run.folder,'status',run.status, ...
  'metrics',run.metrics,'acceptance',run.acceptance,'error',run.error);
 write(base,status);fprintf('END_FULL %s %s\n',c.name,run.status);
 assert(strcmp(run.status,'completed'),run.error);
end
status.completed=true;status.phase='completed';write(base,status);
end
function write(base,status)
fid=fopen(fullfile(base,'status.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(status,'PrettyPrint',true));fclose(fid);
end
