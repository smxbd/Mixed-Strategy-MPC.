function report=validate_predictor(cfg,data)
if nargin<2, data=prepare_sequences(cfg); end
target=data.validation.Y.*data.sigmaY+data.muY; names={'lastvalue','lstm','transformer'};
anchor=repmat(data.validation.current(:,1:4),1,cfg.control.horizon);
if isfield(data,'target_mode')&&strcmp(data.target_mode,'lastvalue_residual'), target=target+anchor; end
report=struct; folder=create_run_directory(cfg,'prediction_validation');
for k=1:numel(names)
 if k==1
  prediction=repmat(data.validation.current(:,1:4),1,cfg.control.horizon);
 else
  a=load(fullfile(cfg.model_dir,[names{k} '_1.mat']),'artifact');
  prediction=predict(a.artifact.net,data.validation.X,'MiniBatchSize',128);
  prediction=prediction.*a.artifact.sigmaY+a.artifact.muY;
  if isfield(a.artifact,'target_mode')&&strcmp(a.artifact.target_mode,'lastvalue_residual'), prediction=prediction+anchor; end
 end
 error=prediction-target; rmse=sqrt(mean(error.^2,1)); mae=mean(abs(error),1);
 report.(names{k})=struct('RMSE',reshape(rmse,4,[])','MAE',reshape(mae,4,[])');
 save(fullfile(folder,[names{k} '.mat']),'prediction','target','rmse','mae');
end
report.split='validation_only'; report.folder=folder; save(fullfile(folder,'report.mat'),'report');
end
