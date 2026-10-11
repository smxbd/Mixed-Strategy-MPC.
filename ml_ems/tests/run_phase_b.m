function run_phase_b
cfg=experiment_config; folder=create_run_directory(cfg,'phase_b'); diary(fullfile(folder,'phase_b.log'));
state=struct('parameter_parity','not_run','build','not_run','short_run','not_run','full_city','not_run');
try
 p=init_all_params; old=load(fullfile(cfg.paths.project,'parameter.mat'));
 fields=intersect(fieldnames(p),fieldnames(old)); mismatches={};
 for k=1:numel(fields), if ~isequaln(p.(fields{k}),old.(fields{k})), mismatches{end+1}=fields{k}; end, end %#ok<AGROW>
 assert(isempty(mismatches),'Parameter mismatch: %s',strjoin(mismatches,',')); state.parameter_parity='passed';
 fprintf('Parameter parity: %d fields passed\n',numel(fields));
 for name={'city200','suburban400','stress300'}, cycle=load_cycle(name{1}); save(fullfile(cfg.paths.root,'cycles','generated',[name{1} '.mat']),'cycle'); end
 build_emt_ml(cfg); state.build='passed';
 cfg.stop_time=30; short=run_experiment(cfg,'city200',1,1); state.short_run=short.status; state.short_folder=short.folder;
 assert(strcmp(short.status,'completed'),'Short baseline failed.');
 cfg.stop_time=200; full=run_experiment(cfg,'city200',1,1); state.full_city=full.status; state.full_folder=full.folder;
catch ME
 state.error=getReport(ME,'extended','hyperlinks','off'); disp(state.error);
end
save(fullfile(folder,'phase_b_status.mat'),'state');
fid=fopen(fullfile(folder,'phase_b_status.json'),'w'); fprintf(fid,'%s',jsonencode(state,'PrettyPrint',true)); fclose(fid);
disp(state); diary off;
end
