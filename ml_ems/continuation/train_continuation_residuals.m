function report=train_continuation_residuals(project_root)
% Prespecified residual recipe; all normalization and weighting use training only.
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems; cfg=continuation_config(project_root);
outputs=fullfile(fileparts(fileparts(project_root)),'outputs');
source=fullfile(outputs,'stageD_initial_training','sequences.mat'); loaded=load(source,'data'); data=loaded.data;
assert(isempty(intersect(unique(data.train.trajectory),unique(data.validation.trajectory))));
folder=create_run_directory(cfg,'weighted_residual_training');
oldMu=double(data.muY); oldSigma=double(data.sigmaY);
for split={'train','validation'}
 b=data.(split{1}); absolute=double(b.Y).*oldSigma+oldMu;
 residual=absolute-repmat(double(b.current(:,1:4)),1,cfg.control.horizon);
 b.Y=residual; data.(split{1})=b;
end
data.muY=zeros(size(oldMu)); data.sigmaY=max(std(data.train.Y,0,1),1e-6);
for split={'train','validation'}
 b=data.(split{1}); b.Y=single(b.Y./data.sigmaY); data.(split{1})=b;
end
% Integer sample replication gives weighted MSE without changing target units.
b=data.train; n=numel(b.X); transient=zeros(n,1);
for k=1:n
 raw=double(b.X{k}).*double(data.sigmaX(:))+double(data.muX(:));
 transient(k)=abs(raw(1,end)-raw(1,end-1))/cfg.control.Ts;
end
ordered=sort(transient); transientThreshold=ordered(max(1,ceil(.8*n)));
ordered=sort(abs(b.current(:,2))); loadThreshold=ordered(max(1,ceil(.8*n)));
weights=1+double(transient>transientThreshold)+double(abs(b.current(:,2))>loadThreshold);
indices=repelem((1:n)',weights);
for field={'X','Y','current','policy','trajectory'}, b.(field{1})=b.(field{1})(indices,:); end
data.train=b; data.target_mode='lastvalue_residual';
data.dataset.folder=folder; data.dataset.source_sequences=source;
recipe=struct('source_sha256',file_sha256(source),'original_windows',n,'weighted_windows',numel(indices), ...
 'sample_weights',weights,'transient_threshold_kmh_s',transientThreshold,'load_threshold_kW',loadThreshold, ...
 'rule','1 + training upper-quintile absolute speed-change + training upper-quintile absolute demand; integer replication weighted MSE', ...
 'test_data_used',false,'validation_weighted',false);
cfg.model_dir=fullfile(folder,'models'); cfg.ensemble_size=3; cfg.epochs=30; cfg.seed=5100;
save(fullfile(folder,'training_input.mat'),'cfg','data','recipe','-v7.3');
report=struct('status','training','folder',folder,'completed',{{}},'learned_closed_loop_allowed',false);
save(fullfile(folder,'report.mat'),'report');
try
 train_sequence_model(cfg,data,'lstm',1); report.completed{end+1}='lstm_1'; save(fullfile(folder,'report.mat'),'report');
 for member=1:3
  train_sequence_model(cfg,data,'transformer',member); report.completed{end+1}=sprintf('transformer_%d',member);
  save(fullfile(folder,'report.mat'),'report'); fprintf('TRAINED=%s\n',report.completed{end});
 end
 report.validation=validate_predictor(cfg,data); report.status='trained_pending_independent_test';
catch exception
 report.status='failed'; report.error=getReport(exception,'extended','hyperlinks','off');
 save(fullfile(folder,'report.mat'),'report'); rethrow(exception)
end
save(fullfile(folder,'report.mat'),'report'); fprintf('RESIDUAL_TRAINING=%s\n',folder);
end
