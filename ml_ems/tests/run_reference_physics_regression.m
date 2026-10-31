function status=run_reference_physics_regression(project,base)
if nargin<1,project=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(project,'ml_ems'));paths=startup_ml_ems;
if nargin<2
 base=fullfile(paths.results,['reference_physics_regression_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
end
assert(~isfolder(base),'EMS:NoOverwrite','Choose a fresh regression output directory.');mkdir(base);
stage=fullfile(project,'ml_ems');
addpath(fullfile(stage,'models'),fullfile(stage,'evaluation'),fullfile(stage,'continuation'),fullfile(stage,'tests'),'-begin');
set(groot,'DefaultFigureVisible','off');
status=struct('phase','unit_tests','passed',false,'transformer_allowed',false,'cases',struct([]));
writejson(fullfile(base,'regression_status.json'),status);
results=runtests(fullfile(stage,'tests','PhysicalTorqueAuditTest.m'));
writetable(table(results),fullfile(base,'unit_test_results.csv'));assert(all([results.Passed]),'EMS:UnitTests','Torque audit unit tests failed.');
cfg=continuation_config(project);
cfg.p=init_baseline_params();cfg.paths=paths;cfg.paths.models=fullfile(base,'candidate_models');
cfg.paths.results=fullfile(base,'build_runs');mkdir(cfg.paths.models);mkdir(cfg.paths.results);
info=build_emt_ml(cfg);save(fullfile(base,'candidate_build.mat'),'cfg','info');
[source,referenceHash]=reference_model_source(project);
referenceDir=fullfile(base,'reference_test_model');
if ~isfile(fullfile(referenceDir,'EMT.mdl'))
mkdir(referenceDir);
txt=fileread(source);
for cb={'<P Name="PreLoadFcn">parameter;</P>','<P Name="InitFcn">parameter;</P>', ...
 '<P Name="StopFcn">save(&apos;result.mat&apos;);</P>'},txt=strrep(txt,cb{1},'');end
fid=fopen(fullfile(referenceDir,'EMT.mdl'),'w','n','UTF-8');fprintf(fid,'%s',txt);fclose(fid);
old=pwd;cd(referenceDir);
fields=fieldnames(cfg.p);for k=1:numel(fields),assignin('base',fields{k},cfg.p.(fields{k}));end
open_system(fullfile(referenceDir,'EMT.mdl'));
observerInfo=add_reference_observers('EMT');adapt_cycle_inputs('EMT'); %#ok<NASGU>
save_system('EMT');close_system('EMT',0);cd(old);
end
assert(strcmpi(file_sha256(source),referenceHash));
p=cfg.p;
original=struct('name','original200','time',p.Time(:),'v_ref',p.v_cyc(:), ...
 'road_resistance',.045+zeros(numel(p.Time),1),'grade',zeros(numel(p.Time),1), ...
 'steering_angle',zeros(numel(p.Time),1),'aux_power',interp1(p.Time_ele,p.ele_map,p.Time(:)));
cycles={original,build_city200,build_stress300,build_suburban400};
status.phase='full_existing_parity';status.reference_sha256=referenceHash;
writejson(fullfile(base,'regression_status.json'),status);
for k=1:numel(cycles)
 c=cycles{k};folder=fullfile(base,'parity',c.name);mkdir(folder);
 writejson(fullfile(base,'current_case.json'),struct('cycle',c.name,'phase','reference','requested_end_s',c.time(end)));
 ref=simulate_case('EMT',fullfile(referenceDir,'EMT.mdl'),cfg,c,fullfile(folder,'reference'));
 writejson(fullfile(base,'current_case.json'),struct('cycle',c.name,'phase','Existing','requested_end_s',c.time(end)));
 cand=simulate_case('EMT_ML',fullfile(cfg.paths.models,'EMT_ML.slx'),cfg,c,fullfile(folder,'Existing'));
 comparison=compare_complete(ref,cand);writetable(comparison,fullfile(folder,'parity.csv'));
 one=struct('cycle',c.name,'requested_end_s',c.time(end),'reference_end_s',ref.physical.time(end), ...
  'existing_end_s',cand.physical.time(end),'samples',numel(cand.physical.time), ...
  'passed',all(comparison.Passed),'max_error',max(comparison.MaxAbsoluteError));
 status.cases=[status.cases one];status.passed=all([status.cases.passed]);
 writejson(fullfile(base,'regression_status.json'),status);
 assert(one.passed,'EMS:ParityFailed','Full Existing parity failed for %s. Transformer gate remains closed.',c.name);
 if ~strcmp(c.name,'original200')
  dataDir=fullfile(base,'comparison_data');if ~isfolder(dataDir),mkdir(dataDir);end
  run=cand;save(fullfile(dataDir,[c.name '_Existing.mat']),'run','-v7.3');
 end
 fprintf('FULL_PARITY_PASS %s samples=%d maxerror=%.12g\n',c.name,one.samples,one.max_error);
end
verify_reference_scope_parity(base);
status.phase='all_existing_parity_passed';status.passed=true;status.transformer_allowed=true;
status.candidate_sha256=file_sha256(fullfile(cfg.paths.models,'EMT_ML.slx'));
writejson(fullfile(base,'regression_status.json'),status);
fprintf('TRANSFORMER_GATE_OPEN\n');
end
function run=simulate_case(model,source,cfg,c,folder)
mkdir(folder);copyfile(source,fullfile(folder,[model '.slx']));
if strcmp(model,'EMT')
 delete(fullfile(folder,[model '.slx']));copyfile(source,fullfile(folder,'EMT.mdl'));
end
old=pwd;oldGen=Simulink.fileGenControl('getConfig');cleanup=onCleanup(@()restore(model,old,oldGen)); %#ok<NASGU>
cd(folder);Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
 'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
open_system(fullfile(folder,[model '.' extension(model)]));
assert(strcmpi(get_param(model,'FileName'),fullfile(folder,[model '.' extension(model)])), ...
 'EMS:ShadowedModel','Wrong model was loaded.');
cfg.controller_id=1;cfg.stop_time=c.time(end);cfg.seed=20260906;
p=cfg.p;p.Time=c.time';p.v_cyc=c.v_ref';p.Time_ele=c.time';p.ele_map=c.aux_power';
p.cycle_time=c.time';p.cycle_road=c.road_resistance';p.cycle_grade=c.grade';p.cycle_steering=c.steering_angle';
p.controller_id=1;p.controller_name='Existing';p.ems_runtime_config=cfg;
in=Simulink.SimulationInput(model);fields=fieldnames(p);
for k=1:numel(fields)
 if strcmp(model,'EMT'),in=in.setVariable(fields{k},p.(fields{k}));
 else,in=in.setVariable(fields{k},p.(fields{k}),'Workspace',model);end
end
in=in.setModelParameter('StopTime',num2str(c.time(end),17),'ReturnWorkspaceOutputs','on', ...
 'LimitDataPoints','off','SaveTime','on','TimeSaveName','tout');
assert(~isfile(fullfile(folder,'simulation.mat')),'EMS:NoOverwrite','Raw simulation already exists.');
save(fullfile(folder,'run_input.mat'),'p','c','cfg');
rng(cfg.seed,'twister');timer=tic;out=sim(in);seconds=toc(timer);
assert(abs(out.tout(end)-c.time(end))<1e-9,'EMS:IncompleteRun','Simulation stopped early.');
save(fullfile(folder,'simulation.mat'),'out','-v7.3');
physical=out.get('physical_observations');legacy=out.get('legacy_state_audit');action=out.get('original_action_audit');
action.signals.values=normalize_action_log(action);
run=struct('physical',physical,'cfg',cfg,'cycle',c,'folder',folder,'status','completed', ...
 'wall_seconds',seconds,'time',legacy.time(:),'runtime',struct());
run.original_action=action;
if strcmp(model,'EMT_ML')
 tr=out.get('ems_trace');run.time=tr.time;run.trace=tr.signals.values;run.runtime=ems_runtime('last_report',0);
else
 ix=round(run.time/.002)+1;o=physical.signals.values(ix,1:20);u=action.signals.values(ix,:);
 run.trace=[legacy.signals.values o u u zeros(numel(ix),4) nan(numel(ix),1) run.time zeros(numel(ix),8) ones(numel(ix),1)];
end
run.metrics=compute_continuation_metrics(run,cfg);
export_physical_torque_audit(run,cfg.p,fullfile(folder,'physical_torque_audit.csv'));
save(fullfile(folder,'run.mat'),'run','-v7.3');
writejson(fullfile(folder,'status.json'),struct('completed',true,'requested_end_s',c.time(end),'actual_end_s',out.tout(end),'wall_seconds',seconds));
end
function comparison=compare_complete(a,b)
ta=a.physical.time(:);tb=b.physical.time(:);
assert(isequal(ta,tb),'EMS:ParityTimes','Physical timestamps differ; no interpolation.');
x=double(a.physical.signals.values);y=double(b.physical.signals.values);
assert(isequal(size(x),size(y))&&all(isfinite(x),'all')&&all(isfinite(y),'all'));
names={'v_com','v_act','SOC','Voltage','Current','nA_act','nB_act','engine_switch', ...
 'ElectricPower','fg_act','angle','Wheel','Pe_act','PA_ele','PB_ele','Pb_act', ...
 'Te_act','TA_act','TB_act','fuel_L','ne_act'}';
delta=abs(x-y);err=max(delta,[],1)';
passed=all(delta<=1e-8+1e-10*abs(x),1)';
comparison=table(string(names),err,passed,'VariableNames',{'Signal','MaxAbsoluteError','Passed'});
assert(isequal(a.original_action.time,b.original_action.time),'EMS:ActionTimes','Original action times differ.');
u=abs(a.original_action.signals.values-b.original_action.signals.values);
comparison=[comparison;table("original_action_4_channels",max(u,[],'all'),all(u<=1e-8,'all'), ...
 'VariableNames',{'Signal','MaxAbsoluteError','Passed'})];
end
function ext=extension(model)
if strcmp(model,'EMT'),ext='mdl';else,ext='slx';end
end
function restore(model,old,oldGen)
if bdIsLoaded(model),close_system(model,0);end
Simulink.fileGenControl('setConfig','config',oldGen);cd(old);
end
function writejson(path,data)
fid=fopen(path,'w','n','UTF-8');fprintf(fid,'%s',jsonencode(data,'PrettyPrint',true));fclose(fid);
end
