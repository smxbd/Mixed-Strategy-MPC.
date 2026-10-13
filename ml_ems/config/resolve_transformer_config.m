function cfg=resolve_transformer_config(cfg)
% One explicit control-configuration source for controller 7 at every entry.
% Existing and LSTM are returned byte-for-byte equivalent as MATLAB structs.
if cfg.controller_id~=7, return; end
configDir=fileparts(mfilename('fullpath'));
policyFile=fullfile(configDir,'transformer_runtime_policy.json');
policy=jsondecode(fileread(policyFile));
referenceFile=fullfile(configDir,policy.reference_config);
assert(strcmpi(file_sha256(referenceFile),policy.reference_sha256), ...
    'EMS:ConfigReferenceChanged','Transformer reference configuration changed.');
reference=load(referenceFile,'cfg');
profile=policy.default_profile;
if isfield(cfg,'transformer_profile') && ~isempty(cfg.transformer_profile)
    profile=char(cfg.transformer_profile);
end
assert(isfield(policy.profiles,profile),'EMS:UnknownTransformerProfile', ...
    'Unknown Transformer profile: %s',profile);
% Replacing this whole struct removes stale flags and weights from model
% workspace/training-config sources. Plant, cycle, seed and output paths
% remain controlled by the calling experiment.
cfg.control=reference.cfg.control;
% Preserve the active branch's corrected tracking objective while retaining
% the horizon and architecture settings required by the trained artifact.
cfg.control.weights.speed=1.0;
flags=policy.profiles.(profile);
cfg.control.incremental_balance=logical(flags.incremental_balance);
cfg.control.qp_projection=logical(flags.qp_projection);
cfg.control.execution_aware=isfield(flags,'execution_aware') && logical(flags.execution_aware);
% Explicit experiment overrides survive both runner and S-function resolution.
if isfield(cfg,'execution_options')
 allowed={'log_constraint_replay','deliverable_projection','soc_bias_gain', ...
  'soc_bias_max','soc_bias_rate','soc_bias_tau','soc_target','soc_bias_weight', ...
  'terminal_soc_weight','demand_loss_weight','predictor'};
 opts=cfg.execution_options; names=fieldnames(opts);
 assert(all(ismember(names,allowed)),'EMS:UnknownExecutionOption','Unknown execution option.');
 for k=1:numel(names)
  if strcmp(names{k},'terminal_soc_weight')
   cfg.control.weights.terminal_soc=opts.(names{k});
  else
   cfg.control.(names{k})=opts.(names{k});
  end
 end
end
cfg.transformer_profile=profile;
cfg.transformer_config_source=struct('version',policy.version, ...
    'policy_file',policyFile,'policy_sha256',file_sha256(policyFile), ...
    'reference_file',referenceFile,'reference_sha256',policy.reference_sha256, ...
    'expected_model_sha256',policy.model_sha256, ...
    'expected_weights_sha256',policy.weights_sha256,'profile',profile);
end
