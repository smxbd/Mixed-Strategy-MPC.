# Transformer configuration source

Controller 7 reads its control settings from
`config/transformer_reference_config.mat`, a copy of the recorded configuration
of the completed 2026-09-15 Transformer comparison. The file SHA-256 is pinned
in `config/transformer_runtime_policy.json`. This reference includes horizon,
sample times, cost weights and limits, so stale model-workspace control fields
cannot silently take precedence.

The original four profiles differ only in `incremental_balance` and
`qp_projection`. The default is now `executable_actions`, which additionally
enables execution-aware search. Historical profiles remain reproducible.

| Profile | Incremental balance | QP projection |
| --- | --- | --- |
| legacy_flags | false | false |
| incremental_only | true | false |
| qp_only | false | true |
| trained_flags | true | true |
| executable_actions (default) | true | true |

See `TRANSFORMER_EXECUTABLE_ACTIONS.md` for the additional search behavior,
logged command/measurement distinction, and remaining limitations.

`resolve_transformer_config` applies the policy both before run manifests are
saved and at `ems_runtime('reset',...)`. The runtime records `effective_control`
and `config_source`; experiment code compares them to the saved settings.
Existing (1) and LSTM (6) pass through without any configuration modification.
Plant parameters, cycle inputs, initial state, paths and seed belong to the
calling experiment; the policy replaces only `cfg.control` for Transformer.

## Entry points

- `ems_project_app`: resolves the selected Transformer profile and logs its name.
- `run_continuation_experiment`: resolves before saving the manifest.
- `outputs/emt_full_sim_20260915/run_controller_comparison.m`: resolves before
  creating SimulationInput; subsequent runs use new result directories.
- `ems_runtime`: resolves at controller initialization, including when a saved
  model is launched directly.

An explicit `cfg.transformer_profile` overrides the policy's default profile.
Unknown profile names fail with `EMS:UnknownTransformerProfile`.
Change the JSON `default_profile` to select a different named experiment. The
`selection_status` records whether the default has been assessed; neither the
profile name nor successful initialization constitutes performance acceptance.

## Reproduce the two-flag experiment

From the project's `ml_ems` directory:

```matlab
startup_ml_ems;
check_transformer_config_source;
batchDir = run_transformer_config_ablation;
```

The runner simulates all four profiles for the same saved 200 s input, verifies
the repaired model and Transformer weight hashes, exports all physical samples
and the EMS trace, and saves both requested and effective runtime settings.
It preserves the model and weights. Completion does not imply that tracking,
state limits or timing budgets passed.
