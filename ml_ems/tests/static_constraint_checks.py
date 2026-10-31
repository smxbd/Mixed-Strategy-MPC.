"""Independent algebra/source checks. Never imports or starts MATLAB/Simulink.

Run: python ml_ems/tests/static_constraint_checks.py
These checks do NOT execute the MATLAB implementation or establish safety.
"""
import hashlib
import json
import math
from pathlib import Path
import re
import unittest
import zipfile
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[2]
PARAM = loadmat(ROOT / 'parameter.mat', squeeze_me=True)


def scalar(name):
    return float(PARAM[name])


def source(name):
    return (ROOT / 'ml_ems' / name).read_text(encoding='utf-8-sig')


class StaticConstraintChecks(unittest.TestCase):
    def test_falling_envelope_defeats_upstream_saturation(self):
        tau = scalar('Ts_e')
        alpha = math.exp(-.02/tau)
        old_torque, new_limit = 2508., 998.
        actual = alpha*old_torque + (1-alpha)*new_limit
        self.assertGreater(actual, new_limit + 1000)
        self.assertLess((new_limit-alpha*old_torque)/(1-alpha), 0)

    def test_suburban_motorA_has_no_allowed_engine_speed(self):
        no = 4573.033850
        needed = (scalar('a22')*no-scalar('nA_max'))/-scalar('a21')
        self.assertGreater(needed, 4500)
        self.assertGreater(needed, scalar('ne_max'))

    def test_stress_motorB_lag_exceeds_static_target_cap(self):
        no = 759.583558
        upper = (scalar('nB_max')-scalar('b22')*no)/scalar('b21')
        self.assertLess(3389.13514, upper)
        actual = scalar('b21')*3762.782884+scalar('b22')*no
        self.assertGreater(actual, scalar('nB_max'))

    def test_torque_observer_is_not_reference_identity(self):
        te, tau, derivative, previous_reference = 2000., scalar('Ts_e'), -500., 300.
        inferred_input = te+tau*derivative
        bias = inferred_input-previous_reference
        self.assertGreater(bias, 1000)
        self.assertAlmostEqual(previous_reference+bias, inferred_input)

    def test_current_power_bound_on_low_current_branch(self):
        ocv, resistance, current = 950., .5, 80.
        power = (ocv-resistance*current)*current/1000
        reconstructed = (ocv-math.sqrt(ocv**2-4*resistance*power*1000))/(2*resistance)
        self.assertAlmostEqual(reconstructed, current)
        self.assertLessEqual(min(45., power), 45.)
        # If measured power is already high, steady-state caps alone miss
        # the actuator lag. A one-hold recovery request must be lower.
        alpha = math.exp(-.02/.2)
        recovery = (power-alpha*85.)/(1-alpha)
        self.assertLess(recovery, power)
        self.assertAlmostEqual(alpha*85.+(1-alpha)*recovery, power)

    def test_unavailable_power_request_survives_scoring(self):
        requested, upper = 90., 45.
        clipped = min(requested, upper)
        self.assertEqual(max(0, clipped-upper)**2, 0)
        self.assertGreater(max(0, requested-upper)**2, 0)
        code = source('controllers/common/rollout_cost.m')
        self.assertIn('requestedPb=pb;', code)
        self.assertIn('max(0,requestedPb-pbmax).^2', code)

    def test_shared_limits_and_actual_state_are_wired(self):
        for file in ('constraint_residual.m','project_qp.m','executable_power_set.m'):
            code = source('controllers/common/'+file)
            self.assertIn('execution_guard_limits(x,o,previous,cfg)',code)
            self.assertIn('guard.battery_lower',code)
            self.assertIn('guard.battery_upper',code)
        code=source('controllers/common/constraint_residual.m')
        self.assertIn('state=max(state,o(17)-guard.engine_actual_limit)',code)
        self.assertIn('12:size(commandTerms,2)',code)

    def test_repair_scope_and_real_cycle_propagation(self):
        code=source('controllers/common/constraint_guard_enabled.m')
        self.assertIn("{'stress300','suburban400'}",code)
        self.assertIn('cfg.controller_id==7',code)
        self.assertNotIn('city200',code)
        for f in ('models/make_simulation_input.m','continuation/run_continuation_experiment.m'):
            self.assertIn('cfg.cycle_name=c.name',source(f))

    def test_qp_precedes_grid_only_in_repair_scope(self):
        code=source('controllers/common/project_to_feasible_set.m')
        self.assertLess(code.index('[candidate,qpFound]=project_qp'),code.index('[tt,scale]=ndgrid'))
        self.assertIn('if qpFound\n  u=candidate;',code)
        self.assertIn('initialDetail.command<=cfg.control.constraint_tolerance',code)
        qp=source('controllers/common/project_qp.m')
        self.assertIn('if d.command>c.constraint_tolerance, continue; end',qp)
        self.assertIn('solveOptions.MaxIterations=64',qp)

    def test_wrapper_budget_is_additional_and_not_relaxed(self):
        for f in ('evaluation/evaluate_run_acceptance.m','continuation/run_continuation_experiment.m'):
            code=source(f)
            self.assertIn('max_safety_callback_s<=cfg.control.legacy_Ts',code)
            self.assertIn('max_safety_wrapper_s<=cfg.control.legacy_Ts',code)
            self.assertIn('max_decision_wrapper_s<=cfg.control.Ts',code)

    def test_protected_files_match_recorded_hashes(self):
        manifest=ROOT/'ml_ems/repairs/reference_physics_20261025/protected_file_verification.json'
        for item in json.loads(manifest.read_text(encoding='utf-8-sig')):
            path=Path(item['path'])
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),item['sha256'],str(path))
        model=ROOT/'ml_ems/models/EMT_ML.slx'
        self.assertEqual(hashlib.sha256(model.read_bytes()).hexdigest(),
                         '54f0b32b7b2353b3c8c1de7a5ad30be81ac078ffc329bb20658812c34642ab4d')

    def test_readonly_model_chain_evidence(self):
        with zipfile.ZipFile(ROOT/'ml_ems/models/EMT_ML.slx') as z:
            engine=z.read('simulink/systems/system_1200.xml').decode('utf-8')
            parent=z.read('simulink/systems/system_1130.xml').decode('utf-8')
        self.assertIn('TransferFcn',engine)
        self.assertIn('[T 1]',engine)
        self.assertIn('<Value>Ts_e</Value>',parent)
        self.assertIn('1149#out:1',engine)
        self.assertIn('1156#in:1',engine)


if __name__ == '__main__':
    unittest.main(verbosity=2)
