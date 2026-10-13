function forecast=predict_demand(history,cfg,nets)
H=cfg.control.horizon; last=history(end,:);
if cfg.controller_id==5, forecast=repmat(last(1:4),H,1); return; end
if cfg.control.no_history, history=repmat(last,cfg.control.history,1); end
if size(history,1)<cfg.control.history, history=[repmat(history(1,:),cfg.control.history-size(history,1),1);history]; end
members=numel(nets); if cfg.controller_id~=8, members=1; end
forecast=zeros(H,4,members);
for k=1:members
 a=nets{k}; X=((history-a.muX)./a.sigmaX)';
 Y=predict(a.net,{X},'MiniBatchSize',1); Y=Y.*a.sigmaY+a.muY;
 % Historical sequence artifacts may emit a different horizon than the
 % active runtime configuration (the archived LSTM emits 20 steps while
 % the current controller runs 10). Align explicitly before reshaping.
 Y=reshape(double(Y),1,[]); modelH=numel(Y)/4;
 assert(modelH==floor(modelH)&&modelH>0,'EMS:PredictorShape', ...
  'Predictor output has %d values; expected a multiple of 4.',numel(Y));
 Y=reshape(Y,4,modelH)';
 modelTs=cfg.control.Ts;
 if isfield(a,'cfg')&&isfield(a.cfg,'Ts'), modelTs=a.cfg.Ts; end
 modelTime=(1:modelH)*modelTs; runtimeTime=(1:H)*cfg.control.Ts;
 assert(runtimeTime(end)<=modelTime(end)+1e-9,'EMS:PredictorHorizon', ...
  'Requested forecast exceeds the trained physical horizon.');
 if modelH~=H || modelTs~=cfg.control.Ts
  Y=interp1([0 modelTime],[last(1:4);Y],runtimeTime,'linear');
 end
 if isfield(a,'target_mode')&&strcmp(a.target_mode,'lastvalue_residual'), Y=Y+repmat(last(1:4),H,1); end
 forecast(:,:,k)=Y;
end
forecast(:,1,:)=max(0,min(120,forecast(:,1,:))); forecast(:,3,:)=max(0,forecast(:,3,:));
forecast(:,4,:)=max(0,min(.2,forecast(:,4,:)));
end
