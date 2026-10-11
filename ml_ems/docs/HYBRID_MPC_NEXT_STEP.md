# Hybrid MPC / rule reconstruction

Controller ID 9 keeps the revision20 Existing action as its safety fallback and
searches five bounded engine-power candidates at each decision. It does not
load ML artifacts, call Transformer code, or alter the frozen baseline.

The intended next run is a short closed-loop execution using
`run_hybrid_mpc_smoke`, followed by comparison against controller ID 1 under
the same cycle, seed, solver and protection settings. Promote the controller
only if it completes without fallback storms or constraint violations.
