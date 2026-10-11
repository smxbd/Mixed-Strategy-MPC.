function fig = ems_project_app(projectRoot)
%EMS_PROJECT_APP Unified graphical entry point for the EMS experiments.
%   ems_project_app
%   ems_project_app(projectRoot)
%
% The app keeps the existing simulation functions as the execution layer:
%   - baseline short/full test: run_short_simulation
%   - continuation short/full test: run_continuation_experiment

if nargin < 1 || isempty(projectRoot)
    thisFile = mfilename('fullpath');
    projectRoot = fileparts(fileparts(thisFile));
end
projectRoot = char(projectRoot);
assert(isfolder(projectRoot), 'Project folder does not exist: %s', projectRoot);
assert(isfolder(fullfile(projectRoot,'ml_ems')), ...
    'The selected folder does not contain an ml_ems folder: %s', projectRoot);

oldDir = pwd;
cleanupDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>
cd(projectRoot);
addpath(fullfile(projectRoot,'ml_ems'),'-begin');
startup_ml_ems;

controllerNames = { ...
    '1 - 原代码 Existing 策略', ...
    '2 - Transformer 策略', ...
    '3 - LSTM 策略'};
% App-facing IDs are mapped to the internal controller implementations:
% Existing=1, Transformer=7, LSTM=6.
controllerIds = [1 7 6];

lastRun = [];
lastOut = [];
lastRunDir = '';

fig = uifigure('Name','混合 MPC / 规则控制实验入口', ...
    'Position',[100 100 1120 720], ...
    'CloseRequestFcn',@closeApp);
fig.UserData.projectRoot = projectRoot;

main = uigridlayout(fig,[6 4]);
main.RowHeight = {34,34,34,40,'1x',34};
main.ColumnWidth = {110,'1x',110,'1x'};
main.Padding = [12 12 12 12];
main.RowSpacing = 8;
main.ColumnSpacing = 10;

uilabel(main,'Text','测试类型');
modeDrop = uidropdown(main,'Items',{ ...
    '基础模型 - 短时 30 s', ...
    '基础模型 - 全长 200 s', ...
    'Continuation - 短时', ...
    'Continuation - 全长工况'}, ...
    'Value','Continuation - 短时');
modeDrop.Layout.Column = 2;

uilabel(main,'Text','工况');
scenarioDrop = uidropdown(main,'Items',{'city200','suburban400','stress300'}, ...
    'Value','city200');
scenarioDrop.Layout.Column = 4;

uilabel(main,'Text','控制器');
controllerDrop = uidropdown(main,'Items',controllerNames, ...
    'ItemsData',controllerIds,'Value',1);
controllerDrop.Layout.Row = 2;
controllerDrop.Layout.Column = 2;

uilabel(main,'Text','项目目录');
rootField = uieditfield(main,'text','Value',projectRoot,'Editable','off');
rootField.Layout.Row = 2;
rootField.Layout.Column = [3 4];

runButton = uibutton(main,'Text','运行所选实验','ButtonPushedFcn',@runSelected);
runButton.Layout.Row = 3;
runButton.Layout.Column = 1;

plotButton = uibutton(main,'Text','绘制最近结果','ButtonPushedFcn',@plotLatest);
plotButton.Layout.Row = 3;
plotButton.Layout.Column = 2;

openButton = uibutton(main,'Text','打开结果目录','ButtonPushedFcn',@openLatestFolder);
openButton.Layout.Row = 3;
openButton.Layout.Column = 3;

statusLabel = uilabel(main,'Text','状态：已初始化','HorizontalAlignment','left');
statusLabel.Layout.Row = 3;
statusLabel.Layout.Column = 4;

ax = uiaxes(main);
ax.Layout.Row = [4 6];
ax.Layout.Column = [1 2];
title(ax,'尚未绘制结果');
grid(ax,'on');

logArea = uitextarea(main,'Editable','off','Value',{ ...
    '已初始化统一实验入口。'; ...
    '短时/全长、工况和控制器可在上方选择。'});
logArea.Layout.Row = [4 6];
logArea.Layout.Column = [3 4];

appendLog('项目路径: %s',projectRoot);
appendLog('提示: 基础模型测试使用根目录 EMT.mdl；工况和控制器选择对 continuation 测试生效。');

    function runSelected(~,~)
        runButton.Enable = 'off';
        plotButton.Enable = 'off';
        openButton.Enable = 'off';
        statusLabel.Text = '状态：运行中...';
        drawnow;
        try
            mode = modeDrop.Value;
            scenario = scenarioDrop.Value;
            method = controllerDrop.Value;
            closeLoadedModels;

            if startsWith(mode,'基础模型')
                if contains(mode,'短时')
                    stopTime = 30;
                else
                    stopTime = 200;
                end
                appendLog('开始基础模型仿真: %.0f s',stopTime);
                [lastOut,lastRunDir] = run_short_simulation(projectRoot,stopTime);
                lastRun = [];
                t = lastOut.get('tout');
                appendLog('基础模型仿真完成，结束时间 %.3f s',t(end));
            else
                cfg = continuation_config(projectRoot);
                cfg.controller_id = method;
                cfg = resolve_transformer_config(cfg);
                if method == 7
                    appendLog('Transformer 配置: %s',cfg.transformer_profile);
                end
                cycle = load_cycle(scenario,cfg.cycles_dir);
                if contains(mode,'短时')
                    cfg.stop_time = min(30,cycle.time(end));
                else
                    cfg.stop_time = cycle.time(end);
                end
                appendLog('开始 continuation 仿真: %s, method %d, %.3f s', ...
                    scenario,method,cfg.stop_time);
                lastRun = run_continuation_experiment(cfg,cycle,method,cfg.seed);
                lastOut = [];
                lastRunDir = lastRun.folder;
                appendLog('运行状态: %s',lastRun.status);
                if isfield(lastRun,'acceptance')
                    appendLog('验收结果 accepted = %d',lastRun.acceptance.accepted);
                end
                if strcmp(lastRun.status,'failed')
                    appendLog('错误: %s',lastRun.error);
                end
            end
            statusLabel.Text = '状态：完成';
            plotButton.Enable = 'on';
            openButton.Enable = 'on';
        catch ME
            statusLabel.Text = '状态：失败';
            appendLog('失败: %s',ME.message);
            uialert(fig,getReport(ME,'basic','hyperlinks','off'),'实验失败');
        end
        runButton.Enable = 'on';
    end

    function plotLatest(~,~)
        try
            if ~isempty(lastRun) && isstruct(lastRun) && ...
                    isfield(lastRun,'time') && isfield(lastRun,'trace')
                t = lastRun.time(:);
                a = lastRun.trace;
                cla(ax);
                if size(a,2) >= 3
                    yyaxis(ax,'left');
                    plot(ax,t,a(:,1),'--','LineWidth',1.1); hold(ax,'on');
                    plot(ax,t,a(:,2),'LineWidth',1.2);
                    ylabel(ax,'车速 (km/h)');
                    yyaxis(ax,'right');
                    plot(ax,t,a(:,3),'LineWidth',1.2);
                    ylabel(ax,'SOC (%)');
                    legend(ax,{'参考车速','实际车速','SOC'},'Location','best');
                else
                    plot(ax,t,a,'LineWidth',1.1);
                    ylabel(ax,'trace');
                end
                xlabel(ax,'时间 (s)');
                title(ax,'Continuation 最近一次结果');
                grid(ax,'on');
                appendLog('已绘制 continuation 结果。');
            elseif ~isempty(lastOut)
                t = lastOut.get('tout');
                cla(ax);
                plot(ax,t,zeros(size(t)),'LineWidth',1.1);
                xlabel(ax,'时间 (s)');
                ylabel(ax,'');
                title(ax,'基础模型仿真完成（当前模型仅返回 tout）');
                grid(ax,'on');
                appendLog('基础模型当前只配置了 tout 输出，未发现 logsout。');
            else
                uialert(fig,'请先运行一个实验。','没有可绘制的结果');
            end
        catch ME
            appendLog('绘图失败: %s',ME.message);
            uialert(fig,ME.message,'绘图失败');
        end
    end

    function openLatestFolder(~,~)
        if isempty(lastRunDir) || ~isfolder(lastRunDir)
            uialert(fig,'还没有可打开的结果目录。','提示');
            return;
        end
        winopen(lastRunDir);
    end

    function appendLog(format,varargin)
        line = sprintf(format,varargin{:});
        old = logArea.Value;
        if ischar(old), old = {old}; end
        logArea.Value = [old; {line}];
        drawnow limitrate;
    end

    function closeLoadedModels
        if bdIsLoaded('EMT')
            close_system('EMT',0);
        end
        if bdIsLoaded('EMT_ML')
            close_system('EMT_ML',0);
        end
    end

    function closeApp(~,~)
        closeLoadedModels;
        delete(fig);
    end
end
