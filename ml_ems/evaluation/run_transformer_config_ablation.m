function batchDir=run_transformer_config_ablation(outputRoot,profiles)
% Four full 200 s runs; only two control flags differ. No model/weight edits.
paths=startup_ml_ems;
if nargin<1, outputRoot=fullfile(paths.results,'transformer_config_ablation'); end
if ~isfolder(outputRoot), mkdir(outputRoot); end
batchDir=tempname(outputRoot); mkdir(batchDir);
fprintf('ABLATION_OUTPUT=%s\n',batchDir);
policy=jsondecode(fileread(fullfile(paths.root,'config','transformer_runtime_policy.json')));
modelFile=fullfile(paths.models,'EMT_ML.slx');
weightsFile=fullfile(paths.models,'trained','transformer_1.mat');
assert(strcmpi(file_sha256(modelFile),policy.model_sha256),'Unexpected plant model.');
assert(strcmpi(file_sha256(weightsFile),policy.weights_sha256),'Unexpected Transformer weights.');
assert(~bdIsLoaded('EMT_ML'),'Save and close EMT_ML before starting this batch.');
oldDir=pwd; oldGen=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()restore(oldDir,oldGen)); %#ok<NASGU>
% Inspect the saved workspace once, then use SimulationInput for overrides.
open_system(modelFile);
ws=get_param('EMT_ML','ModelWorkspace'); base=getVariable(ws,'ems_runtime_config');
assert(getVariable(ws,'SOC0')==60,'Expected the completed comparison initial SOC.');
t=getVariable(ws,'Time'); assert(t(end)>=200,'Saved cycle is shorter than 200 s.');
close_system('EMT_ML',0);
copyfile(modelFile,fullfile(batchDir,'EMT_ML.slx'));
copyfile(fullfile(paths.root,'config','transformer_runtime_policy.json'),batchDir);
sourceDir=fullfile(batchDir,'source'); mkdir(sourceDir);
code=[dir(fullfile(paths.root,'controllers','*.m'));dir(fullfile(paths.root,'controllers','common','*.m')); ...
 dir(fullfile(paths.root,'config','resolve_transformer_config.m')); ...
 dir(fullfile(paths.root,'evaluation','run_transformer_config_ablation.m'))];
for j=1:numel(code), copyfile(fullfile(code(j).folder,code(j).name),sourceDir); end
copyfile(weightsFile,fullfile(batchDir,'transformer_1.mat'));
save(fullfile(batchDir,'saved_runtime_config.mat'),'base');
if nargin<2, profiles={'legacy_flags','incremental_only','qp_only','trained_flags'}; end
summary=struct([]); referenceControl=[];
for k=1:numel(profiles)
 profile=profiles{k}; folder=fullfile(batchDir,profile); mkdir(folder);
 cfg=base; cfg.controller_id=7; cfg.controller_name='Transformer CEM-MPC';
 cfg.seed=20260906; cfg.stop_time=200; cfg.initial_soc_percent=60;
 cfg.model_dir=fullfile(paths.models,'trained'); cfg.paths=paths;
 cfg.transformer_profile=profile; cfg=resolve_transformer_config(cfg);
 stable=rmfield(cfg.control,{'incremental_balance','qp_projection'});
 if k==1, referenceControl=stable; else, assert(isequaln(stable,referenceControl),'Other control settings changed.'); end
 save(fullfile(folder,'run_config.mat'),'cfg');
 writejson(fullfile(folder,'effective_control.json'),struct('source',cfg.transformer_config_source,'control',cfg.control));
 s=struct('profile',profile,'status','running','completed',false,'error','', ...
   'incremental_balance',cfg.control.incremental_balance,'qp_projection',cfg.control.qp_projection, ...
   'model_sha256',policy.model_sha256,'weights_sha256',policy.weights_sha256, ...
   'RMSE_kmh',NaN,'fuel_L',NaN,'distance_km',NaN,'final_SOC_percent',NaN, ...
   'peak_current_A',NaN,'current_violation_s',NaN,'nA_violation_s',NaN,'peak_nA_rpm',NaN, ...
   'projection_decision_fraction',NaN,'wall_seconds',NaN);
 writejson(fullfile(folder,'status.json'),s);
 fprintf('START_PROFILE=%s\n',profile); timer=tic;
 try
  cd(folder);
  Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
   'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
  open_system(modelFile);
  in=Simulink.SimulationInput('EMT_ML');
  in=in.setVariable('controller_id',7,'Workspace','EMT_ML');
  in=in.setVariable('controller_name',cfg.controller_name,'Workspace','EMT_ML');
  in=in.setVariable('ems_runtime_config',cfg,'Workspace','EMT_ML');
  in=in.setModelParameter('StopTime','200','ReturnWorkspaceOutputs','on', ...
   'LimitDataPoints','off','SaveTime','on','TimeSaveName','tout');
  out=sim(in); s.wall_seconds=toc(timer);
  runtime=ems_runtime('last_report',0);
  assert(isequaln(runtime.effective_control,cfg.control),'Effective runtime config differs from manifest.');
  assert(strcmp(runtime.config_source.profile,profile),'Wrong runtime profile.');
  writejson(fullfile(folder,'runtime_control.json'),struct('source',runtime.config_source,'control',runtime.effective_control));
  save(fullfile(folder,'simulation.mat'),'out','-v7.3');
  save(fullfile(folder,'runtime.mat'),'runtime','-v7.3');
  if isfield(runtime,'execution_commands')
   names={'time_s','decision','requested_power_kW','applied_power_kW','measured_Pe_kW','engine_rpm', ...
    'raw_ne','raw_Te','raw_TA','raw_TB','safe_ne','safe_Te','safe_TA','safe_TB'};
   writetable(array2table(runtime.execution_commands,'VariableNames',names),fullfile(folder,'execution_commands.csv'));
   names={'time_s','planned_power_kW','planned_battery_kW','feasibility_mode','fallback_flag'};
   writetable(array2table(runtime.execution_plan,'VariableNames',names),fullfile(folder,'execution_plan.csv'));
  end
  physical=out.get('physical_observations'); tr=out.get('ems_trace');
  t=double(physical.time(:)); v=double(physical.signals.values);
  assert(all(isfinite(v),'all'),'Nonfinite physical trace.');
  assert(all(tr.signals.values(:,62)==7),'Wrong controller ID.');
  names={'time_s','v_ref','v_act','SOC','Voltage','Current','nA','nB','engine_on', ...
   'aux_power','road','grade','steering','Pe','PA','PB','Pb','Te','TA','TB','fuel'};
  writetable(array2table([t v],'VariableNames',names),fullfile(folder,'physical_named.csv'));
  traceNames=[{'time_s'},cellstr(compose('value_%d',1:62))];
  writetable(array2table([tr.time tr.signals.values],'VariableNames',traceNames),fullfile(folder,'ems_trace.csv'));
  s.final_time=t(end); s.completed=isempty(out.ErrorMessage)&&abs(t(end)-200)<1e-7;
  s.RMSE_kmh=sqrt(trapz(t,(v(:,2)-v(:,1)).^2)/(t(end)-t(1)));
  s.fuel_L=v(end,20)-v(1,20); s.distance_km=trapz(t,v(:,2))/3600;
  s.final_SOC_percent=v(end,3); s.peak_current_A=max(abs(v(:,5)));
  s.current_violation_s=trapz(t,double(abs(v(:,5))>cfg.control.current_max));
  s.nA_violation_s=trapz(t,double(abs(v(:,6))>cfg.p.nA_max)); s.peak_nA_rpm=max(abs(v(:,6)));
  [~,ix]=unique(tr.signals.values(:,53),'stable');
  s.projection_decision_fraction=mean(tr.signals.values(ix,48)>1e-6);
  s.stage_unique=unique(tr.signals.values(:,4))';
  s.runtime_config_verified=true;
  if s.completed, s.status='completed'; else, s.status='early_stop'; end
 catch ME
  s.status='failed'; s.completed=false; s.error=getReport(ME,'extended','hyperlinks','off');
  s.wall_seconds=toc(timer); fprintf('%s\n',s.error);
 end
 if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
 % Cell entries allow failed runs to carry fewer diagnostic fields.
 entry=s; save(fullfile(folder,'summary.mat'),'entry');
 writejson(fullfile(folder,'status.json'),s);
 item=struct('profile',profile,'status',s.status,'RMSE_kmh',s.RMSE_kmh, ...
  'fuel_L',s.fuel_L,'distance_km',s.distance_km,'final_SOC_percent',s.final_SOC_percent, ...
  'peak_current_A',s.peak_current_A,'current_violation_s',s.current_violation_s, ...
  'nA_violation_s',s.nA_violation_s,'peak_nA_rpm',s.peak_nA_rpm, ...
  'projection_decision_fraction',s.projection_decision_fraction,'wall_seconds',s.wall_seconds);
 summary=[summary;item]; %#ok<AGROW>
 writetable(struct2table(summary),fullfile(batchDir,'summary.csv'));
 fprintf('DONE_PROFILE=%s STATUS=%s RMSE=%.6f WALL=%.1f\n',profile,s.status,s.RMSE_kmh,s.wall_seconds);
end
assert(strcmpi(file_sha256(modelFile),policy.model_sha256),'Plant changed during the batch.');
assert(strcmpi(file_sha256(weightsFile),policy.weights_sha256),'Weights changed during the batch.');
fprintf('ABLATION_FINISHED=%s\n',batchDir);
end
function writejson(path,value)
fid=fopen(path,'w','n','UTF-8'); assert(fid>0,'Cannot write %s',path);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
function restore(oldDir,oldGen)
if bdIsLoaded('EMT_ML'), close_system('EMT_ML',0); end
Simulink.fileGenControl('setConfig','config',oldGen); cd(oldDir);
end
