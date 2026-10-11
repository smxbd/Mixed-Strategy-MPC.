function check_transformer_config_source
root=fileparts(fileparts(mfilename('fullpath')));
a=load(fullfile(root,'config','transformer_reference_config.mat'),'cfg');
for id=[1 6]
 c=a.cfg; c.controller_id=id;
 assert(isequaln(c,resolve_transformer_config(c)),'Baseline config changed.');
end
profiles={'legacy_flags','incremental_only','qp_only','trained_flags','executable_actions'};
expected=logical([0 0;1 0;0 1;1 1;1 1]);
for k=1:numel(profiles)
 c=a.cfg; c.controller_id=7; c.transformer_profile=profiles{k};
 c.control.horizon=99; c.control.soc_bias_gain=999;
 r=resolve_transformer_config(c);
 assert(r.control.horizon==a.cfg.control.horizon);
 assert(~isfield(r.control,'soc_bias_gain'),'Stale control setting retained.');
 assert(isequal([r.control.incremental_balance r.control.qp_projection],expected(k,:)));
 assert(r.control.execution_aware==strcmp(profiles{k},'executable_actions'));
 assert(isequaln(r,resolve_transformer_config(r)),'Resolver is not idempotent.');
 assert(isequaln(c.p,r.p) && c.seed==r.seed,'Plant/seed changed.');
end
c.transformer_profile='invalid';
try
 resolve_transformer_config(c); error('Test:ExpectedError','Unknown profile accepted.');
catch ME
 assert(strcmp(ME.identifier,'EMS:UnknownTransformerProfile'));
end
app=continuation_config(fileparts(root)); app.controller_id=7;
app=resolve_transformer_config(app); saved=a.cfg; saved.controller_id=7;
saved=resolve_transformer_config(saved);
assert(isequaln(app.control,saved.control),'App and saved-model control configs differ.');
fprintf('CONFIG_SOURCE_CHECKS_PASS\n');
end
