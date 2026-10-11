function out = run_next_preflight(project_root)
if nargin<1, project_root='C:\Users\LAPTOP1210\Documents\Codex\2026-09-06\files-pasted-by-the-user-matlab\work\Optimal1103_ML_copy'; end
addpath(fullfile(project_root,'ml_ems','continuation'),'-begin');
out=struct();
run_continuation_preflight(project_root);
out.preflight='completed';
cfg=continuation_config(project_root); cfg.stop_time=30;
out.ecms=run_continuation_experiment(cfg,'city200',3,cfg.seed);
end
