function plot_working_points(cfg,run,folder)
if ~isfield(run,'trace'), return; end
if nargin<3, folder=create_run_directory(cfg,'working_points'); end
if ~isfolder(folder), mkdir(folder); end
a=run.trace; p=cfg.p;
fig=figure('Visible','off','Color','w','Position',[100 100 1000 350]); tiledlayout(1,3);
ne=a(:,5); te=a(:,36); na=a(:,25); ta=a(:,37); nb=a(:,26); tb=a(:,38); mode=a(:,4);
if isfield(run,'physical')
 t=run.physical.time; o=run.physical.signals.values;
 ne=interp1(run.time,a(:,5),t,'previous','extrap'); mode=interp1(run.time,a(:,4),t,'previous','extrap');
 te=o(:,17); na=o(:,6); ta=o(:,18); nb=o(:,7); tb=o(:,19);
end
nexttile; hold on;
[levels,lines]=contour(p.ne_map,p.Te_map,p.fuel_map,8,'LineColor',[.65 .65 .65]); clabel(levels,lines,'FontSize',6);
scatter(ne,te,2,mode,'filled'); plot(p.ne_map,p.Te_max_map,'k'); xlabel('Engine speed (rpm)'); ylabel('Torque (Nm)'); title('Engine: BSFC contours (g/kWh)');
nexttile; scatter(na,ta,2,mode,'filled'); hold on; plot(p.nA_map,p.TA_max_map,'k',p.nA_map,p.TA_min_map,'k'); xlabel('Motor A speed (rpm)'); ylabel('Torque (Nm)');
nexttile; scatter(nb,tb,2,mode,'filled'); hold on; plot(p.nB_map,p.TB_max_map,'k',p.nB_map,p.TB_min_map,'k'); xlabel('Motor B speed (rpm)'); ylabel('Torque (Nm)');
bar=colorbar; bar.Label.String='EVT stage';
exportgraphics(fig,fullfile(folder,'working_points.png'),'Resolution',300); exportgraphics(fig,fullfile(folder,'working_points.pdf'),'ContentType','vector'); close(fig);
source_run=run.folder; save(fullfile(folder,'source_run.mat'),'source_run');
end
