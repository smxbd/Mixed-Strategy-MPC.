function report=evaluate_continuation_predictors(project_root,simulation_files,cycle_names)
% Frozen-model trajectory test. No fitting or test-driven model selection.
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems; cfg=continuation_config(project_root);
folder=create_run_directory(cfg,'independent_prediction_test');
H=cfg.control.horizon; W=cfg.control.history;
methods={'lastvalue','lstm','transformer'}; labels={'v_ref_kmh','demand_proxy_kW','aux_power_kW','road_resistance'};
rows=struct('Cycle',{},'Method',{},'Target',{},'Horizon_s',{},'N',{},'RMSE',{},'MAE',{}); trajectoryReports=cell(size(simulation_files));
for q=1:numel(simulation_files)
 loaded=load(simulation_files{q},'out'); trace=loaded.out.ems_trace;
 time=trace.time(:); a=trace.signals.values;
 assert(size(a,2)==62&&all(a(:,62)==1),'Test data must be Existing trajectories');
 assert(max(abs(diff(time)-.02))<1e-7,'Expected 0.02 second trace');
 features=double(a(1:5:end,54:61)); N=size(features,1)-H-W+1;
 assert(N>0&&all(isfinite(features),'all'));
 target=zeros(N,4*H); anchor=zeros(N,4*H); rawX=cell(N,1);
 for j=1:N
  last=j+W-1; rawX{j}=features(j:last,:)';
  target(j,:)=reshape(features(last+1:last+H,1:4)',1,[]);
  anchor(j,:)=repmat(features(last,1:4),1,H);
 end
 tr=struct('cycle',cycle_names{q},'source',simulation_files{q},'source_sha256',file_sha256(simulation_files{q}), ...
  'start_time',time(1),'end_time',time(end),'windows',N,'target',target);
 for m=1:3
  if m==1
   prediction=anchor; weightHash='none';
  else
   file=fullfile(cfg.model_dir,[methods{m} '_1.mat']); model=load(file,'artifact'); art=model.artifact;
   X=cellfun(@(z)single((z-double(art.muX(:)))./double(art.sigmaX(:))),rawX,'UniformOutput',false);
   prediction=double(predict(art.net,X,'MiniBatchSize',128));
   prediction=prediction.*double(art.sigmaY)+double(art.muY);
   if isfield(art,'target_mode')&&strcmp(art.target_mode,'lastvalue_residual'), prediction=prediction+anchor; end
   weightHash=file_sha256(file);
  end
  assert(isequal(size(prediction),size(target))&&all(isfinite(prediction),'all'));
  err=prediction-target; tr.(methods{m})=struct('prediction',prediction,'weights_sha256',weightHash);
  for h=1:H
   for ch=1:4
    e=err(:,4*(h-1)+ch);
    rows(end+1)=struct('Cycle',cycle_names{q},'Method',methods{m},'Target',labels{ch}, ...
     'Horizon_s',h*cfg.control.Ts,'N',N,'RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)));
   end
  end
 end
 trajectoryReports{q}=tr;
end
T=struct2table(rows); writetable(T,fullfile(folder,'horizon_metrics.csv'));
report=struct('status','evaluated','folder',folder,'scope','Independent frozen-model test; trajectory windows are correlated; no statistical independence claim.', ...
 'all_three_fixed_cycles',numel(cycle_names)==3&&all(ismember({'city200','suburban400','stress300'},cycle_names)), ...
 'generalization_evaluated',false,'learned_closed_loop_allowed',false,'targets',{labels},'table',T);
% Gate requires all fixed cycles and separate unseen-parameter evidence. This evaluator alone cannot authorize deployment.
save(fullfile(folder,'report.mat'),'report','trajectoryReports','cfg','-v7.3');
fprintf('INDEPENDENT_TEST=%s\n',folder);
end
