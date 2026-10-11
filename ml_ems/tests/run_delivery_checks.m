function run_delivery_checks
cfg=experiment_config; folder=create_run_directory(cfg,'delivery_checks'); diary(fullfile(folder,'checks.log'));
files=dir(fullfile(cfg.paths.root,'**','*.m')); findings=struct('file',{},'messages',{});
for k=1:numel(files)
 if contains(files(k).folder,[filesep 'results'])||contains(files(k).folder,[filesep 'runtime']), continue; end
 p=fullfile(files(k).folder,files(k).name); messages=checkcode(p,'-id');
 if ~isempty(messages), findings(end+1)=struct('file',p,'messages',messages); end %#ok<AGROW>
end
save(fullfile(folder,'code_analyzer.mat'),'findings');
test_core; finish_baseline_parity; plot_training_results(cfg); aggregate_results(cfg);
diary off;
end
