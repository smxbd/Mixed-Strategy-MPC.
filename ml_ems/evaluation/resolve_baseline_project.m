function project_root = resolve_baseline_project(project_root)
% Accept either the project directory or its ml_ems directory.
if nargin < 1 || isempty(project_root)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
project_root = char(project_root);
if ~isfile(fullfile(project_root,'EMT.mdl')) && ...
        isfile(fullfile(fileparts(project_root),'EMT.mdl'))
    project_root = fileparts(project_root);
end
assert(isfile(fullfile(project_root,'EMT.mdl')), ...
    'EMS:MissingModel','Model file does not exist: %s',fullfile(project_root,'EMT.mdl'));
assert(isfile(fullfile(project_root,'parameter.mat')), ...
    'EMS:MissingParameters','Parameter snapshot does not exist: %s', ...
    fullfile(project_root,'parameter.mat'));
end
