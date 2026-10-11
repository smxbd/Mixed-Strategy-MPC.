function run=run_continuation_experiment(cfg,cycle,method,seed)
% Ensure continuation helpers are available when called from an external
% project root (MATLAB does not automatically add this subfolder).
this_dir=fileparts(mfilename('fullpath'));
% Simulink cleanup restores MATLAB's path after each run, so do this on
% every invocation rather than relying on a prior call having added it.
addpath(this_dir,'-begin');
if nargin<4, seed=cfg.seed; end
if nargin<3, method=cfg.controller_id; end
if isstruct(cycle), c=cycle; else, c=load_cycle(cycle); end
cfg.seed=seed; cfg.controller_id=method;
names=controller_registry; cfg.controller_name=names{method};
cfg=resolve_transformer_config(cfg);
folder=create_run_directory(cfg,sprintf('%s_m%d_s%d',c.name,method,seed));
run=struct('status','running','folder',folder,'cycle',c,'cfg',cfg,'metrics',struct,'error','');
save(fullfile(folder,'manifest.mat'),'cfg','c');
if method==7
 effective=struct('source',cfg.transformer_config_source,'control',cfg.control);
 fid=fopen(fullfile(folder,'effective_control.json'),'w','n','UTF-8');
 fprintf(fid,'%s',jsonencode(effective,'PrettyPrint',true)); fclose(fid);
end
assert(~bdIsLoaded('EMT_ML'),'Save and close EMT_ML before running.');
old=pwd; oldGen=Simulink.fileGenControl('getConfig');
restore=onCleanup(@()restore_environment(old,oldGen)); %#ok<NASGU>
cd(folder); timer=tic;
try
 if method==2, assert(cfg.dp_plan.feasible_rollout,'EMS:DPInfeasible','SOC-only DP has no feasible rollout; no closed-loop result claimed.'); end
 copyfile(fullfile(cfg.paths.models,'EMT_ML.slx'),fullfile(folder,'EMT_ML.slx'));
 load_system(fullfile(folder,'EMT_ML.slx'));
 for cb={'PreLoadFcn','InitFcn','StopFcn'}
  assert(isempty(get_param('EMT_ML',cb{1})),'Unexpected model callback.');
 end
 Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
 input=Simulink.SimulationInput('EMT_ML');
 p=cfg.p; p.SOC0=cfg.initial_soc_percent; p.mass=p.mass*cfg.mass_scale;
 p.Time=c.time'; p.v_cyc=c.v_ref'; p.Time_ele=c.time'; p.ele_map=c.aux_power';
 p.cycle_time=c.time'; p.cycle_grade=c.grade'; p.cycle_road=c.road_resistance'; p.cycle_steering=c.steering_angle';
 p.controller_id=method; p.controller_name=cfg.controller_name; p.ems_runtime_config=cfg;
 fields=fieldnames(p);
 for k=1:numel(fields), input=input.setVariable(fields{k},p.(fields{k}),'Workspace','EMT_ML'); end
 input=input.setModelParameter('StopTime',num2str(min(c.time(end),cfg.stop_time)),'ReturnWorkspaceOutputs','on','LimitDataPoints','off');
 if cfg.fast_restart, input=input.setModelParameter('FastRestart','on'); end
 out=sim(input); run.wall_seconds=toc(timer); run.runtime=ems_runtime('last_report',0);
 trace=out.get('ems_trace'); run.time=trace.time; run.trace=trace.signals.values;
 if ismember('physical_observations',out.who), run.physical=out.get('physical_observations'); end
 if ismember('Pi_Po',out.who), run.transmission=out.get('Pi_Po'); end
% Simulink may restore the MATLAB path during simulation cleanup; restore
% the helper path immediately before post-processing as well.
addpath(this_dir,'-begin');
old_dir=pwd;
cd(this_dir);
run.metrics=compute_continuation_metrics(run,cfg);
cd(old_dir);
run.status='completed';
 if run.time(end)<min(c.time(end),cfg.stop_time)-.021, run.status='early_stop'; end
 save(fullfile(folder,'simulation.mat'),'out','-v7.3');
catch ME
 run.status='failed'; run.wall_seconds=toc(timer); run.error=getReport(ME,'extended','hyperlinks','off');
end
acceptance=struct('simulation_completed',strcmp(run.status,'completed'),'hard_commands_pass',false,'physical_limits_pass',false, ...
 'online_budget_pass',false,'tracking_comparable',false,'accepted',false);
if isfield(run,'metrics') && ~isempty(fieldnames(run.metrics))
 m=run.metrics;
 acceptance.hard_commands_pass=isfinite(m.constraint_violations)&&m.constraint_violations==0;
 if isfield(m,'safety_infeasible_samples'), acceptance.hard_commands_pass=acceptance.hard_commands_pass&&m.safety_infeasible_samples==0; end
 acceptance.physical_limits_pass=m.physical_violation_samples==0;
 acceptance.online_budget_pass=isfinite(m.max_computation_s)&&m.max_computation_s<=cfg.control.Ts;
 if isfield(m,'max_decision_callback_s'), acceptance.online_budget_pass=acceptance.online_budget_pass&&m.max_decision_callback_s<=cfg.control.Ts; end
 if isfield(m,'max_safety_callback_s'), acceptance.online_budget_pass=acceptance.online_budget_pass&&m.max_safety_callback_s<=cfg.control.legacy_Ts; end
 if isfield(cfg,'reference_RMSE'), acceptance.tracking_comparable=m.RMSE_kmh<=cfg.reference_RMSE+.25; end
 acceptance.accepted=acceptance.simulation_completed&&acceptance.hard_commands_pass&&acceptance.physical_limits_pass&&acceptance.online_budget_pass&&acceptance.tracking_comparable;
end
run.acceptance=acceptance;
if isfield(cfg.control,'reference_balance_soft') && cfg.control.reference_balance_soft
 run.acceptance.accepted=false;
 run.acceptance.experimental_interface=true;
 run.acceptance.interface_note='Reference balance is soft; physical dynamic balance remains unvalidated.';
end
save(fullfile(folder,'run.mat'),'run','-v7.3');
fid=fopen(fullfile(folder,'status.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(rmfield(run,intersect(fieldnames(run),{'trace','time'})),'PrettyPrint',true)); fclose(fid);
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
fprintf('RUN %s %s wall=%.1fs\n',c.name,run.status,run.wall_seconds);
if strcmp(run.status,'failed'), fprintf('%s\n',run.error); end
end

function restore_environment(old,oldGen)
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
Simulink.fileGenControl('setConfig','config',oldGen); cd(old);
end
