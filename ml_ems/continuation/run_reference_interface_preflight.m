function report=run_reference_interface_preflight(project_root)
% Experimental 30 s stress run; no physical-balance or publication acceptance.
if nargin<1, project_root=fileparts(fileparts(fileparts(mfilename('fullpath')))); end
addpath(fullfile(project_root,'ml_ems','continuation'),'-begin');
tests=test_reference_interface(project_root);
report=run_constraint_replay_check(project_root,true);
report.offline_tests=tests;
save(fullfile(report.output_folder,'reference_interface_preflight.mat'),'report');
fprintf('REFERENCE_INTERFACE_PREFLIGHT passed=%d experimental=1\n',report.preflight_passed);
end
