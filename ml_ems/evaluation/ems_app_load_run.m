function [run,folder]=ems_app_load_run(file)
% Read a saved result; never trust its embedded folder from another computer.
a=load(file,'run');
assert(isfield(a,'run'),'EMS:MissingRun','文件不包含 run 结构。');
ems_app_trajectories(a.run);
assert(isfield(a.run,'status') && isfield(a.run,'metrics'), ...
    'EMS:InvalidRun','结果缺少 status 或 metrics 字段。');
run=a.run;
folder=fileparts(char(file));
end
