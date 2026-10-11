function report=evaluate_phaseD2_predictors(cfg,data,splitName)
%EVALUATE_PHASED2_PREDICTORS Evaluate trained predictors without model selection.
arguments
    cfg struct
    data struct
    splitName (1,:) char {mustBeMember(splitName,{'validation','test'})}
end
b=data.(splitName); H=data.horizon;
target=b.Y.*data.sigmaY+data.muY+repmat(b.current,1,H);
anchor=repmat(b.current,1,H);
names={'lastvalue','lstm','transformer'};
report=struct('split',splitName,'target_mode',data.target_mode,'horizon_seconds',H/10, ...
    'models',{names},'metrics',struct);
for k=1:numel(names)
    if k==1
        prediction=anchor;
    else
        saved=load(fullfile(cfg.model_dir,[names{k} '_1.mat']),'artifact'); a=saved.artifact;
        prediction=double(predict(a.net,b.X,'MiniBatchSize',128));
        prediction=prediction.*a.sigmaY+a.muY+anchor;
    end
    error=prediction-target;
    rmse=sqrt(mean(error.^2,1)); mae=mean(abs(error),1);
    first=reshape(error(:,1:4),[],4);
    jump=abs(first(:,2))>12 | abs(first(:,1))>1.5;
    report.metrics.(names{k})=struct('RMSE',reshape(rmse,4,[])','MAE',reshape(mae,4,[])', ...
        'jump_RMSE',sqrt(mean(first(jump,:).^2,1)),'jump_windows',sum(jump),'prediction',prediction,'target',target);
end
end
