function report=run_phaseD2_training(project_root,initialDataset)
%RUN_PHASED2_TRAINING Collect experts, train residual predictors, test fixed cycles.
project_root=resolve_baseline_project(project_root);
root=fullfile(project_root,'ml_ems');
oldPath=path; cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(root,fullfile(root,'config'),fullfile(root,'cycles'),fullfile(root,'models'), ...
    fullfile(root,'evaluation'),fullfile(root,'training'),fullfile(root,'controllers'), ...
    fullfile(root,'controllers','common'),fullfile(root,'controllers','ecms'), ...
    fullfile(root,'controllers','dp'),'-begin');
if nargin<2||isempty(initialDataset)
    active=fullfile(root,'datasets','active_dataset.mat');
    if isfile(active)
        initialDataset=active;
    else
        candidates=dir(fullfile(root,'datasets','*','dataset.mat'));
        assert(~isempty(candidates),'EMS:PhaseD2Dataset','Initial Existing dataset not found.');
        [~,idx]=max([candidates.datenum]); initialDataset=fullfile(candidates(idx).folder,candidates(idx).name);
    end
end
initial=load(initialDataset,'dataset');
folder=fullfile(root,'datasets',['phaseD2_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]); mkdir(folder);
report=struct('status','collecting','folder',folder,'initial_dataset',initialDataset, ...
    'target_mode','lastvalue_residual','prediction_horizon_s',1.0, ...
    'training_weighting','Residual-jump windows are tripled in the training split.', ...
    'experts',{{'Existing heuristic-grid EMS','Approximate causal ECMS','Approximate SOC-only offline DP reference'}}, ...
    'fixed_test_cycles',{{'city200','suburban400','stress300'}},'runs',{{}});
dataset=struct('version','phaseD2-v1','folder',folder,'runs',{initial.dataset.runs}, ...
    'split_rule',['Complete trajectories only; train/validation seed-disjoint; city200, suburban400 ', ...
    'and stress300 fixed tests excluded from training and model selection.']);
save(fullfile(folder,'phaseD2_report.mat'),'report','dataset');
p=init_baseline_params(); cfg=phaseD2_runtime_config(project_root,p);
jobs=[5101 1 3;5102 1 2;5103 1 3;5104 1 2;6101 2 3;6102 2 2];
for k=1:size(jobs,1)
    seed=jobs(k,1); split=ternary(jobs(k,2)==1,'train','validation'); method=jobs(k,3);
    base=ternary_cycle(mod(seed,2)==1,'city200','suburban400');
    cycle=perturb_cycle(load_cycle(base),seed,split,60);
    fprintf('PHASED2_EXPERT split=%s seed=%d method=%d\n',split,seed,method);
    local=cfg; local.seed=seed;
    [out,runFolder,runCfg]=run_phaseD2_simulation(project_root,p,cycle,method,local);
    run=make_run(out,cycle,method,seed,runCfg,'expert');
    save(fullfile(runFolder,'run.mat'),'run','-v7.3');
    dataset.runs{end+1}=struct('folder',runFolder,'status','completed','split',split, ...
        'seed',seed,'family',base,'expert',method,'source','phaseD2_full_simulation');
    report.runs{end+1}=dataset.runs{end};
    save(fullfile(folder,'dataset.mat'),'dataset'); save(fullfile(folder,'phaseD2_report.mat'),'report','dataset');
end
report.status='training'; save(fullfile(folder,'phaseD2_report.mat'),'report','dataset');
data=prepare_phaseD2_sequences(dataset,30,10);
cfg.seed=20260907; cfg.epochs=40; cfg.batch_size=128; cfg.ensemble_size=1;
cfg.model_dir=fullfile(folder,'models'); mkdir(cfg.model_dir);
train_lstm(cfg,data); train_transformer(cfg,data);
report.validation=evaluate_phaseD2_predictors(cfg,data,'validation');
for name={'city200','suburban400','stress300'}
    cycle=load_cycle(name{1});
    fprintf('PHASED2_TEST cycle=%s\n',name{1});
    [out,runFolder,runCfg]=run_phaseD2_simulation(project_root,p,cycle,1,cfg);
    run=make_run(out,cycle,1,7000+numel(report.runs),runCfg,'fixed_test');
    save(fullfile(runFolder,'run.mat'),'run','-v7.3');
    dataset.runs{end+1}=struct('folder',runFolder,'status','completed','split','test', ...
        'seed',7000+numel(report.runs),'family',name{1},'expert',1,'source','fixed_cycle_existing');
    report.runs{end+1}=dataset.runs{end};
    save(fullfile(folder,'dataset.mat'),'dataset');
end
data=prepare_phaseD2_sequences(dataset,30,10);
report.test=evaluate_phaseD2_predictors(cfg,data,'test');
write_report(folder,report);
save(fullfile(folder,'sequences.mat'),'data','-v7.3');
save(fullfile(folder,'phaseD2_report.mat'),'report','dataset','cfg');
report.status='completed'; save(fullfile(folder,'phaseD2_report.mat'),'report','dataset','cfg');
fprintf('PHASED2_COMPLETED=%s\n',folder);
end

function run=make_run(out,cycle,method,seed,cfg,kind)
trace=double(out.ems_trace.signals.values); time=double(out.ems_trace.time(:));
assert(size(trace,2)==62&&all(isfinite(trace(:,[1:47 54:61])),'all'),'EMS:PhaseD2Trace','Invalid EMS trace.');
run=struct('status','completed','trace',trace,'time',time,'cycle',cycle, ...
    'controller_id',method,'seed',seed,'cfg',cfg,'kind',kind);
end

function value=ternary(condition,yes,no)
if condition, value=yes; else, value=no; end
end

function cycle=ternary_cycle(condition,yes,no)
cycle=ternary(condition,yes,no);
end

function write_report(folder,report)
fid=fopen(fullfile(folder,'README.md'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Phase D2 prediction and expert-data run\n\n');
fprintf(fid,'- Target: last-observation residual, 1.0 s horizon at 0.1 s intervals.\n');
fprintf(fid,'- Training weighting: residual-jump windows are tripled.\n');
fprintf(fid,'- Experts: Existing, approximate causal ECMS, approximate SOC-only offline DP.\n');
fprintf(fid,'- Fixed tests: city200, suburban400, stress300; excluded from training and model selection.\n');
fprintf(fid,'- DP is a reduced SOC-state offline reference, not a full-plant global optimum.\n\n');
for split={'validation','test'}
    if ~isfield(report,split{1}), continue; end
    fprintf(fid,'## %s\n\n',split{1});
    for name={'lastvalue','lstm','transformer'}
        m=report.(split{1}).metrics.(name{1}); r=sqrt(mean(m.RMSE.^2,1));
        fprintf(fid,'- %s: aggregate RMSE [speed, demand, aux, road] = [%.4f, %.4f, %.4f, %.4f].\n', ...
            name{1},r(1),r(2),r(3),r(4));
    end
    fprintf(fid,'\n');
end
end
