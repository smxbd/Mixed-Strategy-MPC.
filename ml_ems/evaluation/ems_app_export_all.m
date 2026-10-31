function report=ems_app_export_all(resultsDir,progressFcn)
% Export every completed saved run, one at a time, without rerunning Simulink.
% Optional callback receives (index,total,folder) before each saved run.
if nargin<2, progressFcn=[]; end
assert(isempty(progressFcn) || isa(progressFcn,'function_handle'), ...
    'EMS:InvalidProgressCallback','进度回调必须是函数句柄。');
assert(isfolder(resultsDir),'EMS:MissingResults','结果目录不存在：%s',resultsDir);
entries=dir(fullfile(resultsDir,'*','run.mat'));
report=struct('exported',0,'failed',0,'skipped',0,'folders',{{}},'errors',{{}});
for index=1:numel(entries)
    folder=entries(index).folder;
    if ~isempty(progressFcn), progressFcn(index,numel(entries),folder); end
    try
        saved=load(fullfile(folder,'run.mat'),'run');
        assert(isfield(saved,'run') && isfield(saved.run,'status'), ...
            'EMS:InvalidRun','结果缺少 run.status。');
        if ~strcmp(saved.run.status,'completed')
            report.skipped=report.skipped+1;
            continue;
        end
        ems_app_export(saved.run,folder);
        report.exported=report.exported+1;
        report.folders{end+1}=folder;
        fprintf('EXPORTED %s\n',folder);
    catch ME
        report.failed=report.failed+1;
        report.errors{end+1}=sprintf('%s: %s',folder,ME.message);
        fprintf('EXPORT_FAILED %s: %s\n',folder,ME.message);
    end
    drawnow limitrate;
end
end
