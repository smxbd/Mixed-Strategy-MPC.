function plot_comparison(cfg,runs,folder)
% Figure contract: compare actual trajectories, with no assumed performance winner.
% Quantitative grid; all observed points retained; no clipping of working points.
colors=lines(8); fig=figure('Visible','off','Color','w','Units','centimeters','Position',[1 1 18.3 17]);
tiledlayout(3,1,'TileSpacing','compact'); labels={};
for panel=1:3
 nexttile; hold on;
 for k=1:numel(runs)
  a=load(fullfile(runs{k},'run.mat'),'run'); r=a.run; if ~isfield(r,'trace'), continue; end
  switch panel, case 1, y=r.trace(:,21); case 2, y=r.trace(:,22); case 3, y=r.trace(:,39)-r.trace(1,39); end
  plot(r.time,y,'Color',colors(r.cfg.controller_id,:),'LineWidth',1); labels{k}=r.cfg.controller_name;
  if panel==1&&k==1, plot(r.time,r.trace(:,20),'k--','HandleVisibility','off'); end
 end
 axisLabels={'Speed (km/h)','SOC (%)','Fuel (L)'}; ylabel(axisLabels{panel}); grid on; box off;
 set(gca,'FontName','Arial','FontSize',8); if panel==3, xlabel('Time (s)'); end
end
legend(labels,'Location','southoutside','NumColumns',2,'Interpreter','none','FontSize',6);
exportgraphics(fig,fullfile(folder,'comparison.pdf'),'ContentType','vector'); exportgraphics(fig,fullfile(folder,'comparison.png'),'Resolution',300);
savefig(fig,fullfile(folder,'comparison.fig')); close(fig);
end
