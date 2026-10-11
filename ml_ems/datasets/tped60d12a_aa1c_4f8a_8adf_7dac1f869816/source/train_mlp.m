function artifact=train_mlp(cfg,data)
if nargin<2, data=prepare_sequences(cfg); end
rng(cfg.seed,'twister'); muY=mean(data.train.policy); sigmaY=max(std(data.train.policy),1e-6);
X=single((data.train.current-data.muX)./data.sigmaX); Y=single((data.train.policy-muY)/sigmaY);
VX=single((data.validation.current-data.muX)./data.sigmaX); VY=single((data.validation.policy-muY)/sigmaY);
layers=[featureInputLayer(8,'Normalization','none');fullyConnectedLayer(64);reluLayer;fullyConnectedLayer(64);reluLayer;fullyConnectedLayer(1);regressionLayer];
options=trainingOptions('adam','MaxEpochs',cfg.epochs,'MiniBatchSize',cfg.batch_size,'InitialLearnRate',1e-3, ...
 'Shuffle','every-epoch','ValidationData',{VX,VY},'ValidationFrequency',20,'ValidationPatience',8, ...
 'OutputNetwork','best-validation-loss','Verbose',false,'Plots','none','ExecutionEnvironment','cpu');
[net,info]=trainNetwork(X,Y,layers,options);
artifact=struct('net',net,'info',info,'muX',data.muX,'sigmaX',data.sigmaX,'muY',muY,'sigmaY',sigmaY,'seed',cfg.seed,'dataset',data.dataset.folder,'method','mlp');
save_artifact(artifact,cfg,'mlp',1);
end
