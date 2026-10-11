function rebuild_recovery_figures(project_root)
root=fullfile(project_root,'ml_ems','results'); out=fullfile(project_root,'recovery_figures'); if ~isfolder(out), mkdir(out); end
spec={
 'city200','Existing','city200_m1_s20261012_20261011_004813_0d4e0b29'; 'city200','LSTM','city200_m6_s20261012_20261011_002701_a5ab1a7b'; 'city200','Transformer','city200_m7_s20261012_20261011_003602_42d0ad6b';
 'suburban400','Existing','suburban400_m1_s20261012_20261011_005425_b8bd05d2'; 'suburban400','LSTM','suburban400_m6_s20261012_20261011_003803_009ebe25'; 'suburban400','Transformer','suburban400_m7_s20261012_20261011_003953_ccbe51de';
 'stress300','Existing','stress300_m1_s20261012_20261011_005728_6da2800b'; 'stress300','LSTM','stress300_m6_s20261012_20261011_004114_02acd34b'; 'stress300','Transformer','stress300_m7_s20261012_20261011_004235_98fc0f0e'};
 cycles={'city200','suburban400','stress300'};
 for ci=1:3
  f=figure('Visible','off','Color','w'); tiledlayout(3,1);
  for ri=1:3
   k=(ci-1)*3+ri; s=load(fullfile(root,spec{k,3},'run.mat'),'run'); r=s.run; t=r.time(:); o=r.trace(:,20:39);
   nexttile; plot(t,o(:,1),'k-',t,o(:,2),'LineWidth',1); grid on; ylabel('Speed (km/h)'); title([cycles{ci} ' - ' spec{k,2}]); legend('reference','actual','Location','best');
  end
  xlabel('Time (s)');
  saveas(f,fullfile(out,[cycles{ci} '_tracking.png']));
  close(f);
 end
end
