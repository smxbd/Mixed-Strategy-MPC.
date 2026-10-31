function [source,expected]=reference_model_source(project)
% Pin the single user-designated model, never a diagnostic model or backup.
manifest=fullfile(project,'model_reference_audit_20261025','reference_manifest.json');
m=jsondecode(fileread(manifest)); source=fullfile(m.reference_directory,'EMT.mdl');
index=find(strcmp({m.files.file},'EMT.mdl'),1);expected=m.files(index).reference_sha256;
assert(isfile(source)&&strcmpi(file_sha256(source),expected), ...
 'EMS:ReferenceChanged','The designated original EMT.mdl is missing or changed.');
end
