function metrics=evaluate_initial_mlp(folder)
s=load(fullfile(folder,'sequences.mat'),'data'); d=s.data;
s=load(fullfile(folder,'models','mlp_1.mat'),'artifact'); a=s.artifact;
x=single((d.validation.current-d.muX)./d.sigmaX);
prediction=double(predict(a.net,x))*a.sigmaY+a.muY;
target=d.validation.policy;
assert(isequal(size(prediction),size(target))&&all(isfinite(prediction),'all'));
delta=prediction-target;
metrics=table(sqrt(mean(delta.^2)),mean(abs(delta)), ...
    'VariableNames',{'ValidationPowerRMSE_kW','ValidationPowerMAE_kW'});
writetable(metrics,fullfile(folder,'mlp_validation_metrics.csv'));
save(fullfile(folder,'mlp_validation_predictions.mat'),'prediction','target','metrics');
disp(metrics);
end
