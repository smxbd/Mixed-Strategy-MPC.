function cfg = experiment_config(root_dir,varargin)
if nargin<1||isempty(root_dir), root_dir=fileparts(fileparts(mfilename('fullpath'))); end
cfg = init_controller_params(varargin{:});
cfg.p = init_baseline_params();
cfg.root_dir = char(root_dir);
cfg.results_dir=fullfile(cfg.root_dir,'results'); cfg.datasets_dir=fullfile(cfg.root_dir,'datasets'); cfg.models_dir=fullfile(cfg.root_dir,'models'); cfg.cycles_dir=fullfile(cfg.root_dir,'cycles','generated');
% Backward-compatible path bundle used by batch and snapshot utilities.
cfg.paths=struct('root',cfg.root_dir,'results',cfg.results_dir,'datasets',cfg.datasets_dir,'models',cfg.models_dir,'cycles',cfg.cycles_dir);
cfg.model_dir=cfg.models_dir; cfg.results_root=cfg.results_dir; cfg.dataset_dir=cfg.datasets_dir;
cfg.seed=cfg.random_seed; cfg.stop_time=inf; cfg.fast_restart=false; cfg.initial_soc_percent=cfg.initial_soc; cfg.mass_scale=1;
dirs={cfg.results_dir,cfg.datasets_dir,cfg.models_dir,cfg.cycles_dir}; for i=1:numel(dirs), if ~exist(dirs{i},'dir'), mkdir(dirs{i}); end, end; rng(cfg.random_seed,'twister');
end
