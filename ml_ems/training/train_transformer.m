function artifacts=train_transformer(cfg,data)
if nargin<2, data=prepare_sequences(cfg); end
artifacts=cell(1,cfg.ensemble_size);
for k=1:cfg.ensemble_size, artifacts{k}=train_sequence_model(cfg,data,'transformer',k); end
end
