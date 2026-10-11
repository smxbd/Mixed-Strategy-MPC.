function folder=snapshot_source(cfg)
folder=create_run_directory(cfg,'source_snapshot'); files=dir(fullfile(cfg.paths.root,'**','*.m')); manifest=struct('file',{},'sha256',{});
for k=1:numel(files)
 source=fullfile(files(k).folder,files(k).name); rel=erase(source,[cfg.paths.root filesep]);
 if startsWith(rel,['results' filesep])||startsWith(rel,['analysis' filesep]), continue; end
 dest=fullfile(folder,rel); if ~isfolder(fileparts(dest)), mkdir(fileparts(dest)); end
 copyfile(source,dest); manifest(end+1)=struct('file',rel,'sha256',file_sha256(source)); %#ok<AGROW>
end
copyfile(fullfile(cfg.paths.models,'EMT_ML.slx'),fullfile(folder,'EMT_ML.slx'));
manifest(end+1)=struct('file','EMT_ML.slx','sha256',file_sha256(fullfile(cfg.paths.models,'EMT_ML.slx')));
weights=dir(fullfile(cfg.model_dir,'*.mat')); mkdir(fullfile(folder,'trained_weights'));
for k=1:numel(weights)
 source=fullfile(weights(k).folder,weights(k).name);
 copyfile(source,fullfile(folder,'trained_weights',weights(k).name));
 manifest(end+1)=struct('file',fullfile('trained_weights',weights(k).name),'sha256',file_sha256(source)); %#ok<AGROW>
end
save(fullfile(folder,'manifest.mat'),'manifest','cfg');
fid=fopen(fullfile(folder,'manifest.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true)); fclose(fid);
end
