classdef MotorSpeedFeasibilityTest < matlab.unittest.TestCase
 methods(Test)
  function emptyHighSpeedInterval(t)
   [s,x,o,c]=fixture();x(4)=3;s.no=4573.033850;
   g=motor_speed_feasibility(s,x,o,c);
   t.verifyTrue(g.static_infeasible);t.verifyGreaterThan(g.static_lower_rpm,4500);
  end
  function stressIsStaticallyFeasible(t)
   [s,x,o,c]=fixture();x(4)=3;s.no=759.583558;s.ne=3762.782884;
   g=motor_speed_feasibility(s,x,o,c);
   t.verifyFalse(g.static_infeasible);t.verifyLessThan(g.static_upper_rpm,s.ne);
   t.verifyLessThan(3389.13514,g.static_upper_rpm);
  end
  function roadOnlyMotorCannotBeFixedByEngineReference(t)
   [s,x,o,c]=fixture();x(4)=1;s.no=6001/c.p.b12;
   g=motor_speed_feasibility(s,x,o,c);t.verifyTrue(g.static_infeasible);
  end
  function noInventedReferenceAuthority(t)
   [s,x,o,c]=fixture();x(4)=3;s.ne=3000;s.no=1000;s.derivative_valid=true;
   s.ne_rate=100;s.ne_acceleration=200;s.no_rate=-10;
   o(6:7)=[c.p.a21*s.ne+c.p.a22*s.no,c.p.b21*s.ne+c.p.b22*s.no];
   g=motor_speed_feasibility(s,x,o,c);h=[.02 .04];
   expected=[c.p.a21;c.p.b21]*(s.ne+h*100+100*h.*(h+.02))+ ...
    [c.p.a22;c.p.b22]*(s.no-10*h);
   t.verifyEqual(g.forecast_motor_rpm,expected,'AbsTol',1e-9);
   t.verifyFalse(g.command_response_certified);t.verifyTrue(g.forecast_valid);
  end
  function shiftHasNoFalseCertificate(t)
   [s,x,o,c]=fixture();x(4)=2;g=motor_speed_feasibility(s,x,o,c);
   t.verifyFalse(g.mode_known);t.verifyFalse(g.forecast_valid);
   t.verifyTrue(all(isnan(g.forecast_motor_rpm),'all'));
  end
  function guardKeepsEngineProtection(t)
   [s,x,o,c]=fixture();x(4)=3;c.controller_id=7;c.cycle_name='stress300';
   c.control.guard_state=s;expected=engine_torque_guard(s,c);
   g=execution_guard_limits(x,o,[3000 0 0 0],c);
   t.verifyEqual(g.engine_guard,expected);t.verifyFalse(g.prediction_valid);
   t.verifyEqual(g.kinematic_infeasible,g.motor_guard.static_infeasible);
  end
 end
end
function [s,x,o,c]=fixture()
c=init_controller_params();c.p=init_baseline_params();
x=zeros(1,19);x(4)=3;x(5)=3000;x(6)=4200;x(7)=1600;x(9)=2700;
o=zeros(1,20);o(3)=60;o(4)=950;
s=struct('ne',3000,'no',1000,'te',0,'ne_rate',0,'no_rate',0, ...
 'ne_acceleration',0,'observation_period',.02,'derivative_valid',false, ...
 'pending_engine_reference',0,'engine_input_bias',0, ...
 'synchronous_speed',true,'previous_reference',3000);
end
