function path=create_run_directory(cfg,label)
uid=char(java.util.UUID.randomUUID);
path=fullfile(cfg.paths.results,[char(label) '_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '_' uid(1:8)]);
assert(~isfolder(path)); mkdir(path);
end
