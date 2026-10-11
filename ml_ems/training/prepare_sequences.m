function data=prepare_sequences(cfg,dataset)
if nargin<2, d=load(fullfile(cfg.paths.datasets,'active_dataset.mat'),'dataset'); dataset=d.dataset; end
H=cfg.control.horizon; W=cfg.control.history;
data=struct('train',empty_split,'validation',empty_split,'dataset',dataset);
for k=1:numel(dataset.runs)
 entry=dataset.runs{k}; if ~strcmp(entry.status,'completed'), continue; end
 d=load(fullfile(entry.folder,'run.mat'),'run'); run=d.run;
 ix=1:5:size(run.trace,1); a=run.trace(ix,:); features=a(:,54:61);
 power=max(0,a(:,45).*a(:,5)/9549); % expert Te_ref times current speed, kW
 target=features(:,1:4); bucket=data.(entry.split);
 for j=W:size(features,1)-H
  if any(~isfinite(features(j-W+1:j,:)),'all')||any(~isfinite(target(j+1:j+H,:)),'all'), continue; end
  bucket.X{end+1,1}=features(j-W+1:j,:)'; bucket.Y(end+1,:)=reshape(target(j+1:j+H,:)',1,[]);
  bucket.current(end+1,:)=features(j,:); bucket.policy(end+1,1)=power(j);
  bucket.trajectory(end+1,1)=entry.seed;
 end
 data.(entry.split)=bucket;
end
assert(~isempty(data.train.X)&&~isempty(data.validation.X),'EMS:Dataset','Need successful train and validation trajectories.');
assert(isempty(intersect(unique(data.train.trajectory),unique(data.validation.trajectory))),'Trajectory leakage');
data.muX=mean(data.train.current,1); data.sigmaX=max(std(data.train.current,0,1),1e-6);
data.muY=mean(data.train.Y,1); data.sigmaY=max(std(data.train.Y,0,1),1e-6);
for split={'train','validation'}
 b=data.(split{1});
 for j=1:numel(b.X), b.X{j}=single((b.X{j}-data.muX')./data.sigmaX'); end
 b.Y=single((b.Y-data.muY)./data.sigmaY); data.(split{1})=b;
end
save(fullfile(dataset.folder,'sequences.mat'),'data','-v7.3');
end
function s=empty_split
s=struct('X',{{}},'Y',[],'current',[],'policy',[],'trajectory',[]);
end
