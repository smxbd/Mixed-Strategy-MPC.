function finish_baseline_parity
cfg=experiment_config; folders=dir(fullfile(cfg.paths.results,'baseline_parity_*')); [~,i]=max([folders.datenum]); folder=fullfile(folders(i).folder,folders(i).name);
a=load(fullfile(folder,'original_output.mat'),'out'); out=a.out;
runs=dir(fullfile(cfg.paths.results,'city200_m1_s1_*')); [~,ix]=sort([runs.datenum],'descend');
for k=ix
 b=load(fullfile(runs(k).folder,runs(k).name,'run.mat'),'run');
 if b.run.cfg.stop_time==30 && strcmp(b.run.status,'completed'), ref=b.run; break; end
end
v=out.get('v_com_act_Td'); battery=out.get('battery'); pe=out.get('Pe_com_act');
vv=[v.signals.values]; bb=[battery.signals.values]; pp=[pe.signals.values];
disp({battery.signals.label}); disp({pe.signals.label});
report=struct('original_folder',folder,'new_folder',ref.folder,'status','passed','tolerance',cfg.parity);
report.speed_max_abs=max(abs(interp1(ref.time,ref.trace(:,21),v.time)-vv(:,2)));
report.soc_max_abs=max(abs(interp1(ref.time,ref.trace(:,22),battery.time)-bb(:,1)));
newout=load(fullfile(ref.folder,'simulation.mat'),'out');
nv=newout.out.get('v_com_act_Td'); nb=newout.out.get('battery'); np=newout.out.get('Pe_com_act');
report.trace_speed_max_abs=report.speed_max_abs;
report.speed_max_abs=max(abs(interp1(nv.time,[nv.signals(2).values],v.time)-vv(:,2)));
report.soc_max_abs=max(abs(interp1(nb.time,[nb.signals(1).values],battery.time)-bb(:,1)));
report.power_max_abs=max(abs(interp1(ref.time,ref.trace(:,32),pe.time)-pp(:,2)));
report.power_max_abs=max(abs(interp1(np.time,[np.signals(2).values],pe.time)-pp(:,2)));
if report.speed_max_abs>cfg.parity.speed||report.soc_max_abs>cfg.parity.soc||report.power_max_abs>cfg.parity.power, report.status='failed'; end
save(fullfile(folder,'parity_report.mat'),'report');
fid=fopen(fullfile(folder,'parity_report.json'),'w'); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); fclose(fid); disp(report);
end
