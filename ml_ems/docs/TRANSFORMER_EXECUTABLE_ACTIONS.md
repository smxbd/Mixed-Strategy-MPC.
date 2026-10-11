# Transformer: optimize the command that can be issued

The `executable_actions` profile adds `execution_aware=true` to the two flags
in `trained_flags`. Existing and LSTM keep their original control paths.

## Root cause

Previously CEM scored freely sampled engine power. Only after selection did
`action_from_power` and the final projection enforce command bounds. The next
CEM call reused the unexecuted power sequence. In addition, rollout assumed an
optimal engine-speed schedule even though incremental balance retains the
existing regulator's engine-speed target.

## Changes

1. At every Transformer decision, `executable_power_set` derives first-command
   feasible power intervals from measured state, current reference wheel torque,
   the latest issued action, and time since the last safety callback. That time
   is normally 0.02 s, not the optimizer's 0.1 s decision interval.
2. The affine engine/motor balance is intersected with torque, slew and battery
   power limits. Four electrical-power sign regions handle driving and regen.
   The speed target is limited by the same command bounds and slew limits.
3. CEM maps samples into these intervals **before** scoring and refits its
   sampling distribution using the mapped sequences. Its first battery-power
   evaluation uses mapped motor torques. The first fuel evaluation uses measured
   engine speed; later steps follow the retained regulator speed target.
4. The remaining horizon uses a local engine torque/power envelope and slew
   bound. It does not claim full future motor/battery feasibility: future states
   and shifts are still reduced-order predictions and are replanned online.
5. If exact reference wheel torque is unreachable, one protective projection
   supplies an explicitly logged fixed candidate. A failed projection is marked
   unavailable; it is never represented as a feasible optimizer solution.
6. The retained plan is re-anchored to the latest issued engine command after
   each decision and intervening safety callback. Final projection stays active.

The feasible demand line uses exact balance, making it conservative relative
to the final projection's torque-balance tolerance. Later safety callbacks can
still change a command as measurements and reference demands change.

## Evidence and limitations

`runtime.execution_plan` logs time, planned command-equivalent engine power,
first-step battery power, feasibility mode (0: feasible demand line; 1: protective
reference; 2: no feasible command), and fallback flag.

`runtime.execution_commands` logs requested/issued four-component actions,
command-equivalent engine powers, measured engine speed and measured engine power.
Command-equivalent power uses `max(engine_rpm,1600)`, matching the existing
action map. It is not measured physical engine power. Actuator delay and plant
state violations must be evaluated separately in the physical output trace.

Tests replay 400 historical states and verify candidates against the independent
existing constraint evaluator, including motor-power sign changes and impossible
bounds. A full 200 s same-input comparison is stored under
`outputs/transformer_execution_20260916` in the workspace.

Run a fresh experiment explicitly with:

```matlab
startup_ml_ems;
batchDir = run_transformer_config_ablation(outputRoot, {'executable_actions'});
```

No physical model, trained weights, cost weights, or battery-current thresholds
are altered by this profile. State-limit and terminal-SOC acceptance are separate
from command consistency.
