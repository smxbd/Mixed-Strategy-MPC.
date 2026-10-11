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
 if isfield(a,'target_mode')&&strcmp(a.target_mode,'lastvalue_residual'), Y=Y+repmat(last(1:4),1,H); end
 forecast(:,:,k)=reshape(Y,4,H)';
end
forecast(:,1,:)=max(0,min(120,forecast(:,1,:))); forecast(:,3,:)=max(0,forecast(:,3,:));
forecast(:,4,:)=max(0,min(.2,forecast(:,4,:)));
end
