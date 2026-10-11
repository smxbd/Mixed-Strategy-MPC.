function cfg = baseline_validation_config()
cfg.stop_time = 200;
cfg.seed = 20260906;
cfg.parameter_abs_tolerance = 1e-12;
cfg.parameter_rel_tolerance = 1e-12;
% Compare all channels in each Scope, using that Scope's own timestamps.
cfg.scopes = {'v_com_act_Td','battery','Pe_com_act'};
cfg.absolute_tolerances = [1e-6 1e-6 1e-5];
cfg.relative_tolerance = 1e-8;
cfg.time_tolerance = 1e-9;
cfg.notes = 'Scope vectors: speed/request; battery; engine power. All channels compared.';
end
