project=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project,'ml_ems')));
for name={'lstm','transformer'}
 s=load(fullfile(project,'ml_ems','models',[name{1} '_1.mat']),'artifact');
 a=s.artifact; fprintf('%s artifact\n',name{1});
 disp(fieldnames(a));
 if isfield(a,'cfg'), disp(a.cfg); end
 fprintf('muX=%s muY=%s\n',mat2str(size(a.muX)),mat2str(size(a.muY)));
end
s=load(fullfile(project,'ml_ems','config','transformer_reference_config.mat'),'cfg');
disp(s.cfg.control);
files=dir(fullfile(project,'ml_ems','results','city200_m*_s1_*','run.mat'));
for k=1:numel(files)
 s=load(fullfile(files(k).folder,files(k).name),'run');
 fprintf('%s: %s\n',files(k).folder,s.run.status);
 if isfield(s.run,'time'), fprintf('End %.2f\n',s.run.time(end)); disp(s.run.metrics); end
end
