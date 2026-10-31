function ems_app_plot(axesList,data)
% Shared axes contract for the live app and exported scientific trajectories.
for k=1:3, cla(axesList(k)); end
plot(axesList(1),data.time_s,data.reference_kmh,'k--', ...
    data.time_s,data.speed_kmh,'b','LineWidth',1);
ylabel(axesList(1),'速度 (km/h)'); title(axesList(1),'速度跟踪');
legend(axesList(1),{'目标速度','实际速度'},'Location','best');
plot(axesList(2),data.time_s,data.SOC_percent,'LineWidth',1);
ylabel(axesList(2),'SOC (%)'); title(axesList(2),'电池 SOC');
plot(axesList(3),data.time_s,data.fuel_L,'LineWidth',1);
ylabel(axesList(3),'累计油耗 (L)'); title(axesList(3),'累计油耗');
for k=1:3, grid(axesList(k),'on'); xlabel(axesList(k),'时间 (s)'); end
end
