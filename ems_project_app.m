function fig = ems_project_app(projectRoot,varargin)
%EMS_PROJECT_APP Visual entry for the current EMT_ML three-controller workflow.
%   ems_project_app opens the app from any working directory once on the path.
%   ems_project_app(projectRoot,'Visible','off') supports automated UI checks.
if nargin<1 || isempty(projectRoot), projectRoot=fileparts(mfilename('fullpath')); end
projectRoot=char(projectRoot);
assert(isfolder(fullfile(projectRoot,'ml_ems')),'EMS:MissingProject', ...
    'Project does not contain ml_ems: %s',projectRoot);
ip=inputParser; addParameter(ip,'Visible','on'); parse(ip,varargin{:});
addpath(fullfile(projectRoot,'ml_ems')); startup_ml_ems;
busy=false; lastRun=[]; lastRunDir='';
fig=uifigure('Name','EMS 统一仿真与绘图入口','Position',[80 80 1200 820], ...
    'Visible',ip.Results.Visible,'CloseRequestFcn',@closeApp);
fig.UserData=struct('projectRoot',projectRoot,'lastRun',[],'lastRunDir','');
main=uigridlayout(fig,[7 4]);
main.RowHeight={32,32,36,36,'1x','1x','1x'};
main.ColumnWidth={110,'1x',110,'1x'};
main.Padding=[12 12 12 12];
put(uilabel(main,'Text','工况'),1,1);
scenario=uidropdown(main,'Items',{'city200','suburban400','stress300'},'Tag','scenario'); put(scenario,1,2);
batchButton=uibutton(main,'Text','运行全部（3控制器 × 3工况）','Tag','runAll', ...
    'ButtonPushedFcn',@runAll); put(batchButton,1,[3 4]);
put(uilabel(main,'Text','控制器'),2,1);
method=uidropdown(main,'Items',{'Existing EMS (1)','LSTM CEM-MPC (6)','Transformer CEM-MPC (7)'}, ...
    'ItemsData',[1 6 7],'Value',1,'Tag','controller'); put(method,2,2);
status=uilabel(main,'Text','状态：就绪','Tag','status'); put(status,2,[3 4]);
runButton=uibutton(main,'Text','运行所选仿真','Tag','run','ButtonPushedFcn',@runSelected); put(runButton,3,1);
loadButton=uibutton(main,'Text','加载已有 run.mat','Tag','load','ButtonPushedFcn',@loadSaved); put(loadButton,3,2);
exportButton=uibutton(main,'Text','导出图表 / CSV','Tag','export','Enable','off', ...
    'ButtonPushedFcn',@exportLatest); put(exportButton,3,3);
openButton=uibutton(main,'Text','打开结果目录','Tag','open','Enable','off', ...
    'ButtonPushedFcn',@openLatest); put(openButton,3,4);
exportAllButton=uibutton(main,'Text','导出全部已有结果','Tag','exportAll', ...
    'ButtonPushedFcn',@exportAll); put(exportAllButton,4,[1 2]);
put(uilabel(main,'Text','扫描 ml_ems/results，导出所有已完成结果'),4,[3 4]);
axesList=gobjects(1,3);
for k=1:3
    axesList(k)=uiaxes(main,'Tag',sprintf('trajectory%d',k)); put(axesList(k),k+4,[1 2]);
    grid(axesList(k),'on');
end
title(axesList(1),'速度跟踪'); ylabel(axesList(1),'速度 (km/h)');
title(axesList(2),'电池 SOC'); ylabel(axesList(2),'SOC (%)');
title(axesList(3),'累计油耗'); ylabel(axesList(3),'油耗 (L)'); xlabel(axesList(3),'时间 (s)');
logArea=uitextarea(main,'Editable','off','Value',{'就绪：选择工况与控制器后运行。'},'Tag','log');
put(logArea,[5 7],[3 4]);
appendLog('项目：%s',projectRoot);
appendLog('模型：EMT_ML.slx；使用 experiment_config 配置，seed=1。');
appendLog('结果保存位置：ml_ems/results。');
appendLog('仿真同步执行，运行期间请等待；completed 与验收通过分别显示。');

    function runSelected(~,~)
        runJobs(method.Value,{scenario.Value});
    end

    function runAll(~,~)
        runJobs(method.ItemsData,scenario.Items);
    end

    function runJobs(controllerIds,scenarioNames)
        if busy, return; end
        busy=true; setBusy(true);
        status.Text='状态：准备仿真...'; drawnow;
        total=numel(controllerIds)*numel(scenarioNames);
        completed=0; failed=0; job=0;
        % Check once before starting the batch, preserving any open user model.
        if bdIsLoaded('EMT_ML')
            status.Text='状态：失败';
            appendLog('EMT_ML 已打开。请先保存并关闭该模型，然后重试。');
            finishBusy;
            return;
        end
        for cycleIndex=1:numel(scenarioNames)
        for methodIndex=1:numel(controllerIds)
        job=job+1;
        appendLog('任务 %d/%d：%s，控制器 %d。',job,total, ...
            scenarioNames{cycleIndex},controllerIds(methodIndex));
        try
            cfg=experiment_config(fullfile(projectRoot,'ml_ems'));
            cfg.controller_id=controllerIds(methodIndex); cfg.seed=1;
            names=controller_registry; cfg.controller_name=names{cfg.controller_id};
            cfg=resolve_transformer_config(cfg);
            assert(isfile(fullfile(cfg.models_dir,'EMT_ML.slx')),'EMS:MissingModel','EMT_ML.slx 不存在。');
            if ismember(cfg.controller_id,[6 7]), load_trained_models(cfg); end
            cycle=load_cycle(scenarioNames{cycleIndex},cfg.cycles_dir);
            cfg.stop_time=cycle.time(end);
            appendLog('开始 %s，%s，%.1f s。',cycle.name,cfg.controller_name,cfg.stop_time);
            if cfg.controller_id==7, appendLog('Transformer profile：%s',cfg.transformer_profile); end
            status.Text=sprintf('状态：仿真运行中（%d/%d）...',job,total); drawnow;
            result=run_experiment(cfg,cycle,cfg.controller_id,cfg.seed);
            lastRun=result; lastRunDir=result.folder; publish;
            status.Text=['状态：' result.status];
            appendLog('运行状态：%s；结果目录：%s',result.status,result.folder);
            if isfield(result,'acceptance')
                appendLog('验收 accepted=%d（仿真完成不等于控制性能验收通过）。',result.acceptance.accepted);
            end
            if isfield(result,'trace') && ~isempty(result.trace)
                showRun;
                data=ems_app_trajectories(result);
                writetable(data,fullfile(lastRunDir,'trajectories.csv'));
                appendLog('已保存 trajectories.csv；可点击“导出图表 / CSV”保存 PNG、PDF、FIG。');
            else
                for axisIndex=1:3, cla(axesList(axisIndex)); end
            end
            if strcmp(result.status,'completed')
                completed=completed+1;
            else
                failed=failed+1;
                appendLog('详情：%s',result.error);
            end
        catch ME
            failed=failed+1;
            status.Text='状态：失败';
            appendLog('失败 [%s]：%s',ME.identifier,ME.message);
        end
        end
        end
        if total>1
            status.Text=sprintf('状态：批量结束，完成 %d/%d，失败 %d',completed,total,failed);
            appendLog('批量结束：共 %d 组，仿真完成 %d 组，失败 %d 组。',total,completed,failed);
        end
        finishBusy;
    end

    function loadSaved(~,~)
        if busy, return; end
        [file,folder]=uigetfile('*.mat','选择统一结果 run.mat',fullfile(projectRoot,'ml_ems','results'));
        if isequal(file,0), return; end
        try
            [result,resultFolder]=ems_app_load_run(fullfile(folder,file));
            lastRun=result; lastRunDir=resultFolder; publish; showRun;
            status.Text=['状态：已加载 ' lastRun.status];
            appendLog('已加载 %s',fullfile(folder,file));
            if isfield(lastRun,'acceptance'), appendLog('验收 accepted=%d',lastRun.acceptance.accepted); end
            setBusy(false);
        catch ME
            appendLog('加载失败：%s',ME.message);
        end
    end

    function showRun
        data=ems_app_trajectories(lastRun);
        ems_app_plot(axesList,data);
        m=lastRun.metrics;
        if all(isfield(m,{'RMSE_kmh','fuel_L','delta_SOC_percent'}))
            appendLog('RMSE=%.4f km/h；油耗=%.4f L；SOC变化=%.4f 百分点。', ...
                m.RMSE_kmh,m.fuel_L,m.delta_SOC_percent);
        end
    end

    function exportLatest(~,~)
        if busy || isempty(lastRun), return; end
        try
            files=ems_app_export(lastRun,lastRunDir);
            appendLog('已导出：%s',strjoin(files,', '));
        catch ME
            appendLog('导出失败：%s',ME.message);
        end
    end

    function exportAll(~,~)
        if busy, return; end
        busy=true; setBusy(true);
        status.Text='状态：导出全部结果中...'; drawnow;
        try
            report=ems_app_export_all(fullfile(projectRoot,'ml_ems','results'),@exportProgress);
            status.Text=sprintf('状态：导出 %d 组，失败 %d 组，跳过 %d 组', ...
                report.exported,report.failed,report.skipped);
            appendLog('全部导出结束：成功 %d 组，失败 %d 组，跳过未完成 %d 组。', ...
                report.exported,report.failed,report.skipped);
            for exportIndex=1:numel(report.folders)
                appendLog('已导出 PNG / PDF / FIG / CSV：%s',report.folders{exportIndex});
            end
            for errorIndex=1:numel(report.errors), appendLog('导出失败：%s',report.errors{errorIndex}); end
            if report.exported==0 && report.failed==0, appendLog('尚无可导出的已完成仿真结果。'); end
        catch ME
            status.Text='状态：批量导出失败';
            appendLog('批量导出失败：%s',ME.message);
        end
        finishBusy;
    end

    function exportProgress(index,total,folder)
        status.Text=sprintf('状态：导出图表中（%d/%d）...',index,total);
        appendLog('处理结果 %d/%d：%s',index,total,folder);
        drawnow;
    end

    function openLatest(~,~)
        if ~busy && isfolder(lastRunDir), winopen(lastRunDir); end
    end

    function publish
        fig.UserData=struct('projectRoot',projectRoot,'lastRun',lastRun,'lastRunDir',lastRunDir);
    end

    function finishBusy
        busy=false;
        if isvalid(fig), setBusy(false); end
    end

    function setBusy(value)
        enabled=matlab.lang.OnOffSwitchState(~value);
        runButton.Enable=enabled; batchButton.Enable=enabled; loadButton.Enable=enabled;
        method.Enable=enabled; scenario.Enable=enabled; exportAllButton.Enable=enabled;
        exportButton.Enable=~value && ~isempty(lastRun) && isfield(lastRun,'trace') && ~isempty(lastRun.trace);
        openButton.Enable=~value && ~isempty(lastRunDir) && isfolder(lastRunDir);
        drawnow;
    end

    function appendLog(format,varargin)
        logArea.Value=[cellstr(logArea.Value); {sprintf(format,varargin{:})}];
        drawnow limitrate;
    end

    function closeApp(~,~)
        if busy
            appendLog('任务运行中，请等待结束后关闭窗口。');
            return;
        end
        delete(fig);
    end
end

function put(component,row,column)
component.Layout.Row=row; component.Layout.Column=column;
end
