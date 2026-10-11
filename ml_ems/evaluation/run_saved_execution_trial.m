function folder=run_saved_execution_trial(label,options,stopTime,method,cycle)
% Reuse the saved plant and cycle from the reported comparison.
if nargin<2, options=struct; end
if nargin<3, stopTime=200; end
if nargin<4, method=7; end
if nargin<5, cycle=[]; end
paths=startup_ml_ems;
workspace=fileparts(fileparts(paths.project));
root=fullfile(workspace,'outputs','reliability_soc_20260916');
if ~isfolder(root), mkdir(root); end
folder=tempname(root); mkdir(folder);
model=fullfile(paths.models,'EMT_ML.slx');
policy=jsondecode(fileread(fullfile(paths.root,'config','transformer_runtime_policy.json')));
assert(strcmpi(file_sha256(model),policy.model_sha256),'Plant hash mismatch.');
assert(strcmpi(file_sha256(fullfile(paths.models,'trained','transformer_1.mat')),policy.weights_sha256));
assert(~bdIsLoaded('EMT_ML'),'Model already open.');
old=pwd; oldGen=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()restore(old,oldGen));
load_system(model); ws=get_param('EMT_ML','ModelWorkspace');
cfg=getVariable(ws,'ems_runtime_config'); cfg.controller_id=7;
cfg.seed=20260906; cfg.model_dir=fullfile(paths.models,'trained');
cfg.paths=paths; cfg.execution_options=options; cfg=resolve_transformer_config(cfg);
cfg.controller_id=method;
save(fullfile(folder,'config.mat'),'cfg','label','cycle');
cd(folder);
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
 'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
in=Simulink.SimulationInput('EMT_ML');
in=in.setVariable('controller_id',method,'Workspace','EMT_ML');
in=in.setVariable('ems_runtime_config',cfg,'Workspace','EMT_ML');
if ~isempty(cycle)
 values=struct('Time',cycle.time','v_cyc',cycle.v_ref','Time_ele',cycle.time', ...
  'ele_map',cycle.aux_power','cycle_time',cycle.time','cycle_grade',cycle.grade', ...
  'cycle_road',cycle.road_resistance','cycle_steering',cycle.steering_angle');
 names=fieldnames(values);
 for k=1:numel(names), in=in.setVariable(names{k},values.(names{k}),'Workspace','EMT_ML'); end
end
in=in.setModelParameter('StopTime',num2str(stopTime),'ReturnWorkspaceOutputs','on','LimitDataPoints','off');
fprintf('TRIAL %s %s\n',label,folder); wall=tic; out=sim(in); wall=toc(wall);
runtime=ems_runtime('last_report',0);
trace=out.get('ems_trace'); physical=out.get('physical_observations');
assert(abs(physical.time(end)-stopTime)<1e-7,'Incomplete simulation.');
save(fullfile(folder,'evidence.mat'),'runtime','trace','physical','cfg','label','wall','-v7.3');
t=physical.time; v=physical.signals.values; dg=runtime.diagnostics; dec=dg(:,2)>0;
summary=struct('label',label,'folder',folder,'RMSE_kmh',sqrt(trapz(t,(v(:,1)-v(:,2)).^2)/(t(end)-t(1))), ...
 'fuel_L',v(end,20)-v(1,20),'final_SOC_percent',v(end,3), ...
 'command_violations',sum(dg(dec,3)>cfg.control.constraint_tolerance), ...
 'all_command_violations',sum(dg(:,3)>cfg.control.constraint_tolerance), ...
 'current_violation_s',trapz(t,double(abs(v(:,5))>cfg.control.current_max)), ...
 'motor_speed_violation_s',trapz(t,double(abs(v(:,6))>cfg.p.nA_max|abs(v(:,7))>cfg.p.nB_max)), ...
 'max_callback_s',max(dg(:,5)),'max_decision_s',max(dg(dec,5)), ...
 'max_safety_s',max(dg(~dec,5)),'wall_s',wall);
fid=fopen(fullfile(folder,'summary.json'),'w'); fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true)); fclose(fid);
save(fullfile(folder,'summary.mat'),'summary'); disp(summary);
end
function restore(old,oldGen)
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
Simulink.fileGenControl('setConfig','config',oldGen); cd(old);
end
