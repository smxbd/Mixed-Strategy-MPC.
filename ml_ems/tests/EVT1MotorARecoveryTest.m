classdef EVT1MotorARecoveryTest < matlab.unittest.TestCase
 methods(Test)
  function nearLimitUsesTorqueAndTransportDelay(t)
   [x,o,p,c]=fixture();q=evt1_motorA_constraints(x,o,p,c);
   t.verifyTrue(q.active);t.verifySize(q.A,[17 4]);
   t.verifyEqual(q.A(:,1),zeros(17,1));
   t.verifyEqual(q.A(1:2,:),zeros(2,4));
   t.verifyGreaterThan(q.A(3,3),0);t.verifyLessThan(q.A(3,4),0);
   t.verifyFalse(q.command_response_certified);
   t.verifyGreaterThan(q.minimum_engine_reference-c.control.constraint_tolerance,10);
  end
  function unsafeCandidateIsNotHiddenBySafePendingCommand(t)
   [x,o,p,c]=fixture();o(6)=5000;o(17:19)=[1000 -500 1000];p(2:4)=o(17:19);
   safe=evt1_motorA_constraints(x,o,p,c);t.verifyFalse(safe.active);
   raw=[3800 2000 1000 -1000];q=evt1_motorA_constraints(x,o,p,c,raw);
   t.verifyTrue(q.active);
   c1=prepare_evt1_candidate_guard(c,x,o,p,raw);
   t.verifyTrue(c1.control.guard_cache.motor_prediction.active);
   before=execution_guard_limits(x,o,p,c);after=c1.control.guard_cache;
   t.verifyEqual(before.engine_upper,after.engine_upper);
   t.verifyEqual(before.battery_upper,after.battery_upper);
  end
  function recoveryRetainsPhysicalConstraintsWhenSlewConflicts(t)
   [x,o,p,c]=fixture();c.control.rate=zeros(1,4);
   raw=[3800 2000 1000 -1000];c=prepare_evt1_candidate_guard(c,x,o,p,raw);
   [~,normal]=project_qp(raw,x,o,p,p,c);t.verifyFalse(normal);
   [u,recovered]=project_qp(raw,x,o,p,p,c,true);t.verifyTrue(recovered);
   [~,~,d]=constraint_residual(u,x,o,p,c);physical=d.terms;physical(12)=-Inf;
   t.verifyLessThanOrEqual(max(physical),c.control.constraint_tolerance);
   t.verifyGreaterThan(d.terms(12),c.control.constraint_tolerance);
   t.verifyLessThanOrEqual(u(2),c.control.guard_cache.engine_upper);
  end
  function farFromLimitLeavesAllocationUntouched(t)
   [x,o,p,c]=fixture();o(6)=4000;q=evt1_motorA_constraints(x,o,p,c);
   t.verifyFalse(q.active);
  end
  function pidBranchHasNoInventedAuthority(t)
   [x,o,p,c]=fixture();p(2)=0;q=evt1_motorA_constraints(x,o,p,c);
   t.verifyFalse(q.active);
  end
  function suburbanEVT1RemainsInactive(t)
   [x,o,p,c]=fixture();c.cycle_name='suburban400';q=motor_prediction_constraints(x,o,p,c);
   t.verifyFalse(q.active);
  end
  function motionResetAndEngineProtectionArePreserved(t)
   [x,o,p,c]=fixture();before=engine_torque_guard(c.control.guard_state,c);
   c=update_evt1_motion(c,[]);q=evt1_motorA_constraints(x,o,p,c);
   after=engine_torque_guard(c.control.guard_state,c);
   t.verifyFalse(q.active);t.verifyEqual(before,after);
  end
 end
end
function [x,o,previous,c]=fixture()
c=init_controller_params();c.p=init_baseline_params();
c.control.constraint_guard_enabled=true;c.control.motor_dynamics=true;
c.controller_id=7;c.cycle_name='stress300';p=c.p;
x=[300 .5 1 1 3800 4200 1600 0 2400 0 1110 -1110 1110 -1110 0 45 -45 0 0];
o=zeros(1,20);o(3)=60;o(4)=950;o(6)=5980;o(17)=1000;o(13)=3800*1000/9549;
previous=[3800 1000 100 -200];
c.control.guard_state=struct('time',1,'stage',1,'ne',3800,'no',0, ...
 'te',1000,'ne_rate',0,'no_rate',0,'ne_acceleration',0, ...
 'no_acceleration',0,'motor_motion_valid',true,'derivative_valid',true, ...
 'synchronous_speed',true,'observation_period',.02,'pending_engine_reference',1000,'engine_input_bias',0);
end
