function files=ems_app_export(run,folder)
% Export the same native samples displayed in the app, without resampling.
data=ems_app_trajectories(run);
assert(isfolder(folder),'EMS:MissingResults','结果目录不存在：%s',folder);
writetable(data,fullfile(folder,'trajectories.csv'));
fig=figure('Visible','off','Color','w','Position',[100 100 1000 800]);
cleanup=onCleanup(@()close(fig));
tiledlayout(fig,3,1); axesList=gobjects(1,3);
for k=1:3, axesList(k)=nexttile; end
ems_app_plot(axesList,data);
exportgraphics(fig,fullfile(folder,'overview.png'),'Resolution',200);
exportgraphics(fig,fullfile(folder,'overview.pdf'),'ContentType','vector');
savefig(fig,fullfile(folder,'overview.fig'));
files={'trajectories.csv','overview.png','overview.pdf','overview.fig'};
end
