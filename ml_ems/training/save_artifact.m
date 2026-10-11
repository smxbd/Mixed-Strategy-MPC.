function save_artifact(artifact,cfg,method,member)
if ~isfolder(cfg.model_dir), mkdir(cfg.model_dir); end
file=fullfile(cfg.model_dir,sprintf('%s_%d.mat',method,member));
if isfile(file)
 uid=char(java.util.UUID.randomUUID); copyfile(file,[file '.' uid(1:8) '.backup']);
end
save(file,'artifact','-v7.3');
loss=table((1:numel(artifact.info.TrainingLoss))',artifact.info.TrainingLoss(:),'VariableNames',{'Iteration','TrainingLoss'});
if isfield(artifact.info,'ValidationLoss'), loss.ValidationLoss=artifact.info.ValidationLoss(:); end
writetable(loss,fullfile(cfg.model_dir,sprintf('%s_%d_loss.csv',method,member)));
end
