function report=run_stageD_initial_training(project_root,parity_folder)
% First trainable dataset from the verified Existing branch, not a full expert suite.
project_root=resolve_baseline_project(project_root); root=fullfile(project_root,'ml_ems');
gate=load(fullfile(parity_folder,'parity_report.mat'),'report');
assert(strcmp(gate.report.status,'passed')&&gate.report.stageD_ready&& ...
    gate.report.actions_passed&&all(gate.report.signals.Passed),'EMS:ParityGate','Existing parity must pass first.');
assert(strcmp(gate.report.model_sha256,file_sha256(fullfile(root,'models','EMT_ML.slx'))), ...
    'EMS:ModelChanged','EMT_ML changed after parity verification.');
old_path=path; cleanup=onCleanup(@()path(old_path));
addpath(fullfile(root,'config'),fullfile(root,'cycles'),fullfile(root,'evaluation'), ...
    fullfile(root,'training'),'-begin');
folder=tempname(fullfile(root,'datasets')); mkdir(folder);
report=struct('status','generating','folder',folder,'parity_report',parity_folder, ...
    'expert','Existing heuristic-grid EMS only','stage','D initial training', ...
    'fixed_test_cycles_used',false,'seed',3100,'duration_seconds',60,'epochs',30);
dataset=struct('version','verified-existing-pilot-v1','folder',folder,'runs',{{}}, ...
    'split_rule','Disjoint complete 60-second perturbed trajectories; fixed test cycles excluded.');
p=init_baseline_params(); runtime=[];
save(fullfile(folder,'stageD_report.mat'),'report');
fprintf('STAGED_DIR=%s\n',folder);
try
    for split={'train','validation'}
        if strcmp(split{1},'train'), seeds=3101:3106; else, seeds=4101:4102; end
        for seed=seeds
            if mod(seed,2), base=build_city200(); else, base=build_suburban400(); end
            cycle=perturb_cycle(base,seed,split{1},report.duration_seconds);
            fprintf('GENERATE %s seed=%d family=%s\n',split{1},seed,base.name);
            [out,run_folder,runtime]=run_existing_ml_simulation(project_root,p,cycle);
            trace=out.ems_trace.signals.values; time=out.ems_trace.time(:);
            assert(size(trace,2)==62&&all(trace(:,62)==1));
            assert(all(isfinite(trace(:,[1:47 54:61])),'all'),'EMS:InvalidDataset','Nonfinite observations/actions.');
            assert(max(abs(diff(time)-.02))<1e-8,'EMS:TraceRate','Expected 0.02-second trace.');
            run=struct('status','completed','trace',trace,'time',time,'cycle',cycle, ...
                'controller_id',1,'seed',seed,'cfg',runtime);
            save(fullfile(run_folder,'run.mat'),'run','-v7.3');
            dataset.runs{end+1}=struct('folder',run_folder,'status','completed', ...
                'split',split{1},'seed',seed,'family',base.name,'expert',1);
            save(fullfile(folder,'dataset.mat'),'dataset');
        end
    end
    cfg=runtime; cfg.seed=report.seed; cfg.epochs=report.epochs; cfg.batch_size=128;
    cfg.ensemble_size=1; cfg.control.history=30; cfg.control.horizon=20;
    cfg.model_dir=fullfile(folder,'models'); mkdir(cfg.model_dir);
    cfg.paths.results=fullfile(folder,'validation_results'); mkdir(cfg.paths.results);
    cfg.initial_training_scope='One MLP, one LSTM, one Transformer; Existing-only expert data.';
    save(fullfile(folder,'training_config.mat'),'cfg');
    source_folder=fullfile(folder,'source'); mkdir(source_folder);
    for source={'prepare_sequences','train_mlp','train_lstm','train_transformer', ...
            'train_sequence_model','save_artifact','validate_predictor','perturb_cycle', ...
            'run_existing_ml_simulation','run_stageD_initial_training'}
        copyfile(which(source{1}),source_folder);
    end
    data=prepare_sequences(cfg,dataset);
    report.train_windows=numel(data.train.X); report.validation_windows=numel(data.validation.X);
    report.status='training'; save(fullfile(folder,'stageD_report.mat'),'report');
    fprintf('TRAIN windows=%d validation=%d\n',report.train_windows,report.validation_windows);
    train_mlp(cfg,data); fprintf('MLP_TRAINED\n');
    train_lstm(cfg,data); fprintf('LSTM_TRAINED\n');
    train_transformer(cfg,data); fprintf('TRANSFORMER_TRAINED\n');
    report.prediction_validation=validate_predictor(cfg,data);
    models={'lastvalue','lstm','transformer'}; methods=strings(0,1); channels=strings(0,1); rmse=[]; mae=[];
    labels={'v_ref_kmh','demand_proxy_kW','aux_power_kW','road_resistance'};
    for k=1:numel(models)
        for j=1:4
            methods(end+1,1)=models{k}; channels(end+1,1)=labels{j};
            metrics=report.prediction_validation.(models{k});
            rmse(end+1,1)=sqrt(mean(metrics.RMSE(:,j).^2));
            mae(end+1,1)=mean(metrics.MAE(:,j));
        end
    end
    T=table(methods,channels,rmse,mae,'VariableNames',{'Method','Target','RMSE','MAE'});
    writetable(T,fullfile(folder,'validation_metrics.csv')); disp(T);
    report.status='initial_training_completed'; report.model_dir=cfg.model_dir;
    report.limitations=['Validation split also used for model selection; not a held-out test result. ', ...
        'Only Existing expert, 60-second trajectories, one Transformer member, ordinary MSE. ', ...
        'ECMS/DP experts, fixed-cycle prediction test, uncertainty ensemble and closed-loop ML evaluation remain.'];
catch exception
    report.status='error'; report.reason=getReport(exception,'extended','hyperlinks','off');
    save(fullfile(folder,'stageD_report.mat'),'report');
    fprintf('STAGED_FAILED_REPORT=%s\n',folder); rethrow(exception)
end
save(fullfile(folder,'stageD_report.mat'),'report');
fprintf('STAGED_STATUS=%s\n',report.status);
end
