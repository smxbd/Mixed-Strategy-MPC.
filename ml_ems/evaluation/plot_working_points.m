function plot_working_points(cfg,run,folder)
% One shared Python plotting implementation and one torque accounting contract.
if nargin<3,folder=create_run_directory(cfg,'working_points');end
if ~isfolder(folder),mkdir(folder);end
audit=export_physical_torque_audit(run,cfg.p,fullfile(folder,'physical_torque_audit.csv')); %#ok<NASGU>
run.cfg=cfg;
if isstruct(run.cycle),cycle=run.cycle.name;else,cycle=char(run.cycle);end
method='Transformer';if cfg.controller_id==1,method='Existing';end
source=fullfile(folder,[cycle '_' method '.mat']);
assert(~isfile(source),'EMS:NoOverwrite','Use a new working-point output directory.');
save(source,'run','-v7.3');
python=plotting_python();
script=fullfile(cfg.paths.project,'figure_outputs','plot_two_controllers.py');
command=sprintf('"%s" "%s" --operating-run "%s" --output-dir "%s"',python,script,source,folder);
[status,message]=system(command);assert(status==0,'EMS:PlotFailed','Python plot failed: %s',message);
end

function executable=plotting_python()
explicit=getenv('EMS_PYTHON_EXE');
if ~isempty(explicit),candidates={explicit};
else
 if ispc,[~,found]=system('where.exe python');else,[~,found]=system('which -a python3');end
 candidates=[{'python'};cellstr(splitlines(strtrim(found)))];
end
for k=1:numel(candidates)
 candidate=strtrim(candidates{k});if isempty(candidate),continue;end
 [status,~]=system(sprintf('"%s" -c "import numpy, scipy, h5py, matplotlib, pandas"',candidate));
 if status==0,executable=candidate;return;end
end
error('EMS:PlotRuntime','Set EMS_PYTHON_EXE to a Python runtime with numpy, scipy, h5py, matplotlib and pandas.');
end
