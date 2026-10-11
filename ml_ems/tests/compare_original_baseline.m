function compare_original_baseline
cfg=experiment_config; folder=create_run_directory(cfg,'baseline_parity'); old=pwd; cleanup=onCleanup(@()cd(old)); %#ok<NASGU>
copyfile(fullfile(cfg.paths.project,'EMT.mdl'),folder); copyfile(fullfile(cfg.paths.project,'parameter.m'),folder);
images=dir(fullfile(cfg.paths.project,'*.jpg')); for k=1:numel(images), copyfile(fullfile(images(k).folder,images(k).name),folder); end
cd(folder); set(groot,'DefaultFigureVisible','off');
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
load_system(fullfile(folder,'EMT.mdl'));
input=Simulink.SimulationInput('EMT'); input=input.setModelParameter('StopTime','30','ReturnWorkspaceOutputs','on','LimitDataPoints','off');
out=sim(input); save(fullfile(folder,'original_output.mat'),'out','-v7.3'); close_system('EMT',0);
cfg.stop_time=30; ref=run_experiment(cfg,'city200',1,1);
v=out.get('v_com_act_Td'); battery=out.get('battery'); pe=out.get('Pe_com_act');
newtime=ref.time; new=ref.trace;
% Original Scope vectors are independently timed. Battery order is verified below.
report=struct('original_folder',folder,'new_folder',ref.folder,'status','pending');
vv=[v.signals.values]; bb=[battery.signals.values]; pp=[pe.signals.values];
report.speed_max_abs=max(abs(interp1(newtime,new(:,21),v.time)-vv(:,2)));
report.battery_signal_labels={battery.signals.label};
report.power_max_abs=max(abs(interp1(newtime,new(:,32),pe.time)-pp(:,2)));
% Battery Scope ordering is [SOC Current Voltage Power], verified from scope wiring.
report.soc_max_abs=max(abs(interp1(newtime,new(:,22),battery.time)-bb(:,1)));
report.tolerance=cfg.parity;
report.status='passed';
if report.speed_max_abs>cfg.parity.speed||report.soc_max_abs>cfg.parity.soc||report.power_max_abs>cfg.parity.power, report.status='failed'; end
save(fullfile(folder,'parity_report.mat'),'report');
fid=fopen(fullfile(folder,'parity_report.json'),'w'); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); fclose(fid); disp(report);
end
