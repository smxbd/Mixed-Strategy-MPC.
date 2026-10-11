function run_phase_cd
cfg=experiment_config; folder=create_run_directory(cfg,'phase_cd'); diary(fullfile(folder,'phase_cd.log'));
state=struct('tests','not_run','dataset','not_run','mlp','not_run','lstm','not_run','transformer','not_run');
try
 test_core; state.tests='passed';
 dataset=generate_dataset(cfg); state.dataset=dataset.folder;
 data=prepare_sequences(cfg,dataset); train_mlp(cfg,data); state.mlp='trained';
 train_lstm(cfg,data); state.lstm='trained'; train_transformer(cfg,data); state.transformer='trained';
 report=validate_predictor(cfg,data); state.prediction_validation=report.folder;
catch ME
 state.error=getReport(ME,'extended','hyperlinks','off'); disp(state.error);
end
save(fullfile(folder,'phase_cd_status.mat'),'state');
fid=fopen(fullfile(folder,'phase_cd_status.json'),'w'); fprintf(fid,'%s',jsonencode(state,'PrettyPrint',true)); fclose(fid);
disp(state); diary off;
end
