function catalog=batch_experiments_parallel(cfg,kind,workers)
% Optional high-memory path. Serial batch_experiments is the conservative default.
if nargin<3, workers=2; end
assert(license('test','Distrib_Computing_Toolbox'),'Parallel Computing Toolbox unavailable');
folder=create_run_directory(cfg,[char(kind) '_parallel']); jobs=build_experiment_matrix(cfg,kind);
load_system(fullfile(cfg.paths.models,'EMT_ML.slx'));
for k=1:numel(jobs)
 c=load_cycle(jobs(k).cycle); local=jobs(k).cfg; local.seed=jobs(k).seed;
 if jobs(k).method==2, local.dp_plan=solve_dp(c,local); end
 jobs(k).cfg=local; inputs(k)=make_simulation_input(local,c,jobs(k).method); %#ok<AGROW>
end
pool=gcp('nocreate'); if isempty(pool), parpool('Processes',workers); end
catalog=struct('kind',kind,'folder',folder,'jobs',jobs,'runs',{{}}); save(fullfile(folder,'catalog.mat'),'catalog');
outputs=parsim(inputs,'UseFastRestart','off','ShowProgress','on','ShowSimulationManager','off', ...
 'TransferBaseWorkspaceVariables','off','SetupFcn',@()setup_worker(cfg));
for k=1:numel(outputs)
 j=jobs(k); c=load_cycle(j.cycle); local=j.cfg; local.controller_id=j.method; names=controller_registry; local.controller_name=names{j.method};
 rd=create_run_directory(local,sprintf('%s_parallel_m%d',c.name,j.method));
 run=struct('folder',rd,'cfg',local,'cycle',c,'status','failed','error',outputs(k).ErrorMessage,'metrics',struct, ...
  'wall_seconds',outputs(k).SimulationMetadata.TimingInfo.TotalElapsedWallTime);
 out=outputs(k);
 if isempty(out.ErrorMessage)
  tr=out.get('ems_trace'); run.time=tr.time; run.trace=tr.signals.values;
  if ismember('physical_observations',out.who), run.physical=out.get('physical_observations'); end
  if ismember('Pi_Po',out.who), run.transmission=out.get('Pi_Po'); end
  run.metrics=compute_metrics(run,local); run.status='completed';
  if run.time(end)<min(c.time(end),local.stop_time)-.021, run.status='early_stop'; end
 end
 save(fullfile(rd,'simulation.mat'),'out','-v7.3'); save(fullfile(rd,'run.mat'),'run','-v7.3');
 catalog.runs{end+1}=struct('job_index',k,'folder',rd,'status',run.status,'label',j.label);
end
save(fullfile(folder,'catalog.mat'),'catalog'); export_tables(cfg,catalog,folder); close_system('EMT_ML',0);
end
function setup_worker(cfg)
addpath(cfg.paths.root); startup_ml_ems;
folder=create_run_directory(cfg,'worker'); cd(folder);
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
end
