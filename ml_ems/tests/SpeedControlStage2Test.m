classdef SpeedControlStage2Test < matlab.unittest.TestCase
 methods(Test)
  function noDirectSpeedReferenceAuthority(t)
   [x,o,c]=fixture();q=motor_prediction_constraints(x,o,[3000 1000 100 -200],c);
   t.verifyTrue(q.active);t.verifyEqual(q.A(:,1),zeros(16,1));
   t.verifyEqual(q.A(1:4,:),zeros(4,4));
   t.verifyFalse(q.command_response_certified);
  end
  function engineTorqueHasPhysicalMotorDirections(t)
   [x,o,c]=fixture();q=motor_prediction_constraints(x,o,[3000 1000 100 -200],c);
   t.verifyLessThan(q.A(13,2),0);t.verifyGreaterThan(q.A(14,2),0);
  end
  function unavailableStateDoesNotInventPrediction(t)
   [x,o,c]=fixture();c.control.guard_state.derivative_valid=false;
   q=motor_prediction_constraints(x,o,[3000 1000 100 -200],c);t.verifyFalse(q.active);
  end
  function governorIsDerivedFromOriginalDomain(t)
   [~,~,c]=fixture();cycle=struct('time',[0;1;2],'v_ref',[0;90;110]);
   g=speed_reference_governor(cycle,c.p);factor=(1+c.p.kh)/c.p.kh*c.p.ic/.377/c.p.rz;
   t.verifyEqual(c.p.a21*c.p.ne_min+c.p.a22*factor*g.cap_kmh,6000,'AbsTol',1e-8);
   t.verifyEqual(g.requested_kmh,cycle.v_ref);t.verifyFalse(g.hard_safety_certified);
  end
  function logsNeverLoseRows(t)
   [~,~,c]=fixture();c.stop_time=.04;log=EMSRealtimeLog(c);
   log.append(1,[0 .003]);log.append(2,[0 1 0 0 .002]);
   log.append(1,[.02 .004]);log.append(2,[.02 0 0 0 .003]);
   r=log.export(struct('storage',log));
   t.verifyEqual(r.wrapper_times,[0 .003;.02 .004]);
   t.verifyEqual(r.max_safety_wrapper_s,.004);
  end
 end
end
function [x,o,c]=fixture()
c=init_controller_params();c.p=init_baseline_params();c.control.motor_dynamics=true;
c.cycle_name='stress300';c.controller_id=7;c.control.constraint_guard_enabled=true;
x=[300 .5 1 3 3000 4200 1600 1000 2400 0 1110 -1110 1110 -1110 0 45 -45 0 0];
o=zeros(1,20);o(3)=60;o(4)=950;o(17)=1000;o(13)=3000*1000/9549;
o(6:7)=[c.p.a21 c.p.a22;c.p.b21 c.p.b22]*[3000;1000];
c=update_constraint_guard(c,0,x,o,[3000 1000 100 -200]);
c=update_constraint_guard(c,.02,x,o,[3000 1000 100 -200]);
end
