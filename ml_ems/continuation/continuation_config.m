function cfg=continuation_config(project_root)
% Use the verified Stage D runtime configuration, not the generic stub API.
root=fullfile(project_root,'ml_ems'); addpath(root); paths=startup_ml_ems;
policy=jsondecode(fileread(fullfile(root,'config','transformer_runtime_policy.json')));
referenceFile=fullfile(root,'config',policy.reference_config);
assert(isfile(referenceFile)&&strcmpi(file_sha256(referenceFile),policy.reference_sha256), ...
 'EMS:ConfigReferenceChanged','Frozen runtime reference configuration is missing or changed.');
a=load(referenceFile,'cfg');cfg=a.cfg;
cfg.configuration_source=referenceFile;
cfg.paths=paths; cfg.p=init_baseline_params();
cfg.cycles_dir=fullfile(paths.root,'cycles','generated'); cfg.results_dir=paths.results; cfg.datasets_dir=paths.datasets; cfg.models_dir=paths.models;
candidates={fullfile(paths.models,'trained'),paths.models};
matched=false;
for k=1:numel(candidates)
 artifact=fullfile(candidates{k},'transformer_1.mat');
 if isfile(artifact)&&strcmpi(file_sha256(artifact),policy.weights_sha256)
  cfg.model_dir=candidates{k};matched=true;break
 end
end
assert(matched,'EMS:FrozenWeightsMissing','No Transformer artifact matches the pinned weight hash.');
assert(strcmpi(file_sha256(fullfile(paths.models,'EMT_ML.slx')),policy.model_sha256), ...
 'Model differs from the reference-physics model pinned by the current runtime policy.');
receipt=jsondecode(fileread(fullfile(paths.models,'reference_physics_manifest.json')));
assert(receipt.full_existing_parity_passed&&receipt.all_scope_parity_passed&& ...
 strcmpi(receipt.model_sha256,policy.model_sha256), ...
 'EMS:PhysicsRegressionRequired','Reference-physics parity certificate is missing or mismatched.');
cfg.physics_provenance=receipt;
cfg.version='reference-physics-restored-20261025'; cfg.ensemble_size=1;
cfg.control.incremental_balance=true; cfg.control.qp_projection=true;
cfg.control.warmup=true; cfg.control.rate=double(cfg.control.rate);
cfg.stop_time=30; cfg.fast_restart=false; cfg.mass_scale=1;
cfg.initial_soc_percent=60; cfg.seed=20260906;
end
