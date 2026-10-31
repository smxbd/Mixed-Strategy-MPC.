function paths=startup_ml_ems
paths.root=fileparts(mfilename('fullpath'));
paths.project=fileparts(paths.root);
folders={'continuation','config','cycles','models','controllers','controllers/common','controllers/existing_grid_ems', ...
 'controllers/dp','controllers/ecms','controllers/mlp_policy','controllers/lastvalue_cem', ...
 'controllers/lstm_cem','controllers/transformer_cem','training','evaluation','tests'};
addpath(paths.root);
addpath(paths.project);
for k=1:numel(folders)
 folder=fullfile(paths.root,folders{k});
 if isfolder(folder), addpath(folder); end
end
paths.results=fullfile(paths.root,'results'); paths.datasets=fullfile(paths.root,'datasets');
paths.models=fullfile(paths.root,'models');
end
