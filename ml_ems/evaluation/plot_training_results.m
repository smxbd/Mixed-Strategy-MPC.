function plot_training_results(cfg)
folder=create_run_directory(cfg,'training_figures'); files=dir(fullfile(cfg.model_dir,'*.mat'));
fig=figure('Visible','off','Color','w','Position',[100 100 1000 750]); tiledlayout(3,2,'TileSpacing','compact');
for k=1:numel(files)
 saved=load(fullfile(files(k).folder,files(k).name),'artifact'); a=saved.artifact;
 nexttile; hold on; loss=a.info.TrainingLoss(:);
 plot(1:numel(loss),loss,'DisplayName','Training');
 if isfield(a.info,'ValidationLoss')
  validation=a.info.ValidationLoss(:); valid=find(isfinite(validation));
  plot(valid,validation(valid),'DisplayName','Validation');
 end
 title(strrep(erase(files(k).name,'.mat'),'_',' '));
 xlabel('Iteration'); ylabel('Normalized MSE'); set(gca,'FontName','Arial'); legend('Location','best'); grid on;
end
exportgraphics(fig,fullfile(folder,'training_loss.png'),'Resolution',300); exportgraphics(fig,fullfile(folder,'training_loss.pdf'),'ContentType','vector'); close(fig);
assert(isfield(cfg,'prediction_validation_dir'),'Supply the validation directory belonging to these weights; do not select by date.');
d=load(fullfile(cfg.prediction_validation_dir,'report.mat'),'report'); names={'lastvalue','lstm','transformer'};
fig=figure('Visible','off','Color','w','Position',[100 100 900 650]); tiledlayout(2,2);
for channel=1:4
 nexttile; hold on;
 for k=1:3, plot((1:cfg.control.horizon)*cfg.control.Ts,d.report.(names{k}).RMSE(:,channel),'LineWidth',1.3); end
 units={'Speed RMSE (km/h)','Demand proxy RMSE (kW)','Auxiliary RMSE (kW)','Road coefficient RMSE'};
 xlabel('Forecast horizon (s)'); ylabel(units{channel}); grid on;
end
legend(names,'Location','southoutside'); exportgraphics(fig,fullfile(folder,'validation_prediction_rmse.png'),'Resolution',300);
exportgraphics(fig,fullfile(folder,'validation_prediction_rmse.pdf'),'ContentType','vector'); close(fig);
end
