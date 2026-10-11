function data=prepare_phaseD2_sequences(dataset,history,horizon)
%PREPARE_PHASED2_SEQUENCES Residual targets with trajectory-level splits.
arguments
    dataset struct
    history (1,1) double {mustBeInteger,mustBePositive}=30
    horizon (1,1) double {mustBeInteger,mustBePositive}=10
end
data=struct('train',empty_split,'validation',empty_split,'test',empty_split,'dataset',dataset, ...
    'target_mode','lastvalue_residual','history',history,'horizon',horizon);
for k=1:numel(dataset.runs)
    entry=dataset.runs{k};
    if ~strcmp(entry.status,'completed'), continue; end
    loaded=load(fullfile(entry.folder,'run.mat'),'run'); run=loaded.run;
    ix=1:5:size(run.trace,1); a=double(run.trace(ix,:)); feature=a(:,54:61);
    target=feature(:,1:4);
    bucket=data.(entry.split);
    for j=history:size(feature,1)-horizon
        source=feature(j-history+1:j,:); future=target(j+1:j+horizon,:);
        if any(~isfinite(source),'all')||any(~isfinite(future),'all'), continue; end
        bucket.X{end+1,1}=source';
        bucket.Y(end+1,:)=reshape((future-target(j,:))',1,[]);
        bucket.current(end+1,:)=target(j,:);
        bucket.trajectory(end+1,1)=entry.seed;
        bucket.expert(end+1,1)=entry.expert;
    end
    data.(entry.split)=bucket;
end
assert(~isempty(data.train.X)&&~isempty(data.validation.X),'EMS:PhaseD2Data','Both splits need completed runs.');
assert(isempty(intersect(unique(data.train.trajectory),unique(data.validation.trajectory))), ...
    'EMS:Leakage','A seed occurs in both splits.');
data.muX=mean(data.train.current,1); data.sigmaX=max(std(data.train.current,0,1),1e-6);
data.muY=zeros(1,4*horizon); data.sigmaY=max(std(data.train.Y,0,1),1e-6);
for name={'train','validation','test'}
    b=data.(name{1});
    jump=max(abs(reshape(b.Y(:,1:4),[],4)),[],2)>12 | abs(b.Y(:,1))>1.5;
    if strcmp(name{1},'train')
        repeat=find(jump);
        b.X=[b.X;b.X(repeat);b.X(repeat)];
        b.Y=[b.Y;b.Y(repeat,:);b.Y(repeat,:)];
        b.current=[b.current;b.current(repeat,:);b.current(repeat,:)];
        b.trajectory=[b.trajectory;b.trajectory(repeat);b.trajectory(repeat)];
        b.expert=[b.expert;b.expert(repeat);b.expert(repeat)];
    end
    for j=1:numel(b.X), b.X{j}=single((b.X{j}-data.muX')./data.sigmaX'); end
    b.Y=single(b.Y./data.sigmaY);
    data.(name{1})=b;
end
data.training_weighting='Two additional copies of windows with first-step power residual >12 kW or speed residual >1.5 km/h.';
end

function s=empty_split
s=struct('X',{{}},'Y',[],'current',[],'trajectory',[],'expert',[]);
end
