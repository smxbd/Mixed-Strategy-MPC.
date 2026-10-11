function artifact=train_lstm(cfg,data)
if nargin<2, data=prepare_sequences(cfg); end
artifact=train_sequence_model(cfg,data,'lstm',1);
end
