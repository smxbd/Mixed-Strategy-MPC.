function nets=load_trained_models(cfg)
switch cfg.controller_id
 case 4, file='mlp'; count=1;
 case 6, file='lstm'; count=1;
 otherwise, file='transformer'; count=1;
end
if cfg.controller_id==8, count=cfg.ensemble_size; end
nets=cell(1,count);
for k=1:count
 path=fullfile(cfg.model_dir,sprintf('%s_%d.mat',file,k));
 assert(isfile(path),'EMS:MissingTrainedModel','Trained model missing: %s',path);
 a=load(path,'artifact'); nets{k}=a.artifact;
end
end
