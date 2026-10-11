function train_residual_predictors
cfg=experiment_config; folder=create_run_directory(cfg,'residual_training');
diary(fullfile(folder,'training.log'));
cfg.model_dir=fullfile(folder,'models'); mkdir(cfg.model_dir);
copyfile(fullfile(cfg.paths.models,'trained','mlp_1.mat'),fullfile(cfg.model_dir,'mlp_1.mat'));
source=load(fullfile(cfg.paths.datasets,'active_dataset.mat'),'dataset');
d=load(fullfile(source.dataset.folder,'sequences.mat'),'data'); data=d.data;
for name={'train','validation'}
 b=data.(name{1}); absolute=double(b.Y).*data.sigmaY+data.muY;
 b.Y=absolute-repmat(b.current(:,1:4),1,cfg.control.horizon); data.(name{1})=b;
end
data.muY=zeros(1,4*cfg.control.horizon);
data.sigmaY=max(std(data.train.Y,0,1),1e-6); data.target_mode='lastvalue_residual';
for name={'train','validation'}, data.(name{1}).Y=single(data.(name{1}).Y./data.sigmaY); end
save(fullfile(folder,'sequences.mat'),'data','cfg','-v7.3');
train_lstm(cfg,data); train_transformer(cfg,data);
report=validate_predictor(cfg,data);
save(fullfile(folder,'validation.mat'),'report','cfg');
disp(report); diary off;
end
