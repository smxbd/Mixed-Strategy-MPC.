function report=recheck_existing_ml_parity(prior_folder)
saved=load(fullfile(prior_folder,'parity_report.mat'),'report','cycle','cfg');
report=saved.report; cycle=saved.cycle; cfg=saved.cfg;
folder=tempname(fileparts(prior_folder)); mkdir(folder);
report.previous_report=prior_folder; report.folder=folder;
a=load(fullfile(report.original_folder,'short_simulation_output.mat'),'out');
b=load(fullfile(report.modified_folder,'simulation.mat'),'out');
report.signals=compare_baseline_outputs(a.out,b.out,cfg);
log=b.out.parity_original_action; tr=b.out.ems_trace;
% Regression coverage for both supported logging orientations.
test=struct('time',(0:2)','signals',struct('values',reshape(1:12,1,4,3)));
expected=reshape(1:12,4,3)'; assert(isequal(normalize_action_log(test),expected));
test.signals.values=expected; assert(isequal(normalize_action_log(test),expected));
action=normalize_action_log(log); trace=tr.signals.values;
assert(isequal(size(log.time),size(tr.time))&&all(abs(log.time-tr.time)<cfg.time_tolerance));
assert(size(trace,2)==62&&all(trace(:,62)==1));
report.action_max_abs=max(abs(action-trace(:,44:47)),[],'all');
report.raw_safe_max_abs=max(abs(trace(:,40:43)-trace(:,44:47)),[],'all');
report.actions_passed=all(isfinite(trace(:,40:47)),'all')&&report.action_max_abs==0&&report.raw_safe_max_abs==0;
report.status='failed'; report.stageD_ready=false;
if all(report.signals.Passed)&&report.actions_passed
    report.status='passed'; report.stageD_ready=true;
end
report.action_samples=size(action,1);
report.recheck_reason='Corrected 1-by-4-by-N logging orientation; simulation outputs unchanged.';
writetable(report.signals,fullfile(folder,'signal_parity.csv'));
save(fullfile(folder,'parity_report.mat'),'report','cycle','cfg');
disp(report); fprintf('FINAL_PARITY_DIR=%s\n',folder);
end
