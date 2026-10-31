function run_stage2_local(project,base)
assert(~isfolder(base));mkdir(base);diary(fullfile(base,'local_validation.log'));
cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
addpath(fullfile(project,'ml_ems'));startup_ml_ems;
cfg=continuation_config(project);cfg.paths.results=fullfile(base,'runs');mkdir(cfg.paths.results);cfg.results_dir=cfg.paths.results;
protected={'EMT.mdl','parameter.m','parameter.mat','ml_ems/models/EMT_ML.slx', ...
 'ml_ems/controllers/common/engine_torque_guard.m','ml_ems/controllers/common/update_constraint_guard.m'};
hashes=cell(size(protected));for k=1:numel(protected),hashes{k}=file_sha256(fullfile(project,protected{k}));end
save(fullfile(base,'protected_hashes.mat'),'protected','hashes');
status=struct('phase','preflight','completed',false,'cases',{{}});write(base,status);
for item={{'stress300',60},{'suburban400',355}}
 name=item{1}{1};finish=item{1}{2};startup_ml_ems;c=load_cycle(name);
 cfg.cycle_name=c.name;cfg.stop_time=finish;
 status.phase=['local_' name];write(base,status);
 fprintf('BEGIN_LOCAL %s stop=%.1f seed=%d\n',name,finish,cfg.seed);
 run=run_continuation_experiment(cfg,c,7,cfg.seed);startup_ml_ems;
 status.cases{end+1}=struct('cycle',name,'stop_time',finish,'folder',run.folder, ...
  'status',run.status,'metrics',run.metrics,'acceptance',run.acceptance,'error',run.error);
 write(base,status);assert(strcmp(run.status,'completed'),run.error);
 fprintf('END_LOCAL %s\n',name);
end
for k=1:numel(protected),assert(strcmpi(hashes{k},file_sha256(fullfile(project,protected{k}))));end
status.completed=true;status.phase='completed';status.protected_unchanged=true;write(base,status);
end
function write(base,status)
fid=fopen(fullfile(base,'status.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(status,'PrettyPrint',true));fclose(fid);
end
