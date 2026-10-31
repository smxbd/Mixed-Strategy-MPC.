classdef PhysicalTorqueAuditTest < matlab.unittest.TestCase
 methods(Test)
  function directSpeedOverridesDelayedTrace(tc)
   [run,p]=fixture();run.trace(:,5)=4500;run.physical.signals.values(:,21)=1600;
   run.physical.signals.values(:,17)=1200;
   a=physical_torque_audit(run,p);
   tc.verifyEqual(a.engine_excess,32*ones(3,1));tc.verifyTrue(all(a.engine_violation));
  end
  function strictThresholdAndReserveSign(tc)
   [run,p]=fixture();run.physical.signals.values(:,17)=[1168;1169;1169.001];
   a=physical_torque_audit(run,p);
   tc.verifyEqual(a.engine_violation,[false;false;true]);
   tc.verifyEqual(a.engine_reserve,[0;-1;-1.001],'AbsTol',1e-10);
  end
  function endpointsDoNotExtrapolate(tc)
   [run,p]=fixture();run.physical.signals.values(:,21)=[0;4600;4500];
   a=physical_torque_audit(run,p);
   tc.verifyEqual(a.engine_limit,[1168;998;998]);
   tc.verifyEqual(a.engine_speed_outside,[true;true;false]);
  end
  function asymmetricMotorAndPeakSeparate(tc)
   [run,p]=fixture();p.TA_min_map=-100*ones(1,3);
   run.physical.signals.values(:,18)=[-120;-151;-151.1];
   a=physical_torque_audit(run,p);
   tc.verifyTrue(all(a.A.nominal_violation));
   tc.verifyEqual(a.A.peak_violation,[false;false;true]);
  end
  function overspeedIndependentOfTorque(tc)
   [run,p]=fixture();run.physical.signals.values(:,6)=[0;6001;6000];
   a=physical_torque_audit(run,p);
   tc.verifyEqual(a.A.overspeed,[false;true;false]);
   tc.verifyFalse(any(a.A.peak_violation));
  end
  function legacyPowerIdentityAndZeroTorque(tc)
   [run,p]=fixture();run.physical.signals.values=run.physical.signals.values(:,1:20);
   run.physical.signals.values(:,17)=[100;0;100];
   run.physical.signals.values(:,13)=[100*2000/9549;0;100*3000/9549];
   a=physical_torque_audit(run,p);
   tc.verifyEqual(a.engine_speed([1 3]),[2000;3000],'AbsTol',1e-10);
   tc.verifyTrue(a.engine_limit_unknown(2));tc.verifyEqual(numel(a.time),3);
  end
  function duplicateTimesAreRejected(tc)
   [run,p]=fixture();run.physical.time=[0;0;.004];
   tc.verifyError(@()physical_torque_audit(run,p),'EMS:PhysicalData');
  end
 end
end
function [run,p]=fixture()
p=struct('ne_map',[1600 4200 4500],'Te_max_map',[1168 2508 998], ...
 'nA_map',[-6000 0 6000],'TA_max_map',[600 1110 600], ...
 'TA_min_map',[-600 -1110 -600],'nB_map',[-6000 0 6000], ...
 'TB_max_map',[600 1110 600],'TB_min_map',[-600 -1110 -600]);
o=zeros(3,21);o(:,21)=1600;
run=struct('time',[0;.02;.04],'trace',zeros(3,62), ...
 'physical',struct('time',[0;.002;.004],'signals',struct('values',o)));
end
