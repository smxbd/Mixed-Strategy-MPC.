import sys
from pathlib import Path
source=open('ml_ems/analysis/investigate_evt1_stage3.py',encoding='utf8').read().split(' rows=[]')[0]
suffix='baseline'
if len(sys.argv)>1:
 source=source.replace('motor_speed_stage2_20261026_001/full_regression/status.json',sys.argv[1]);suffix=Path(sys.argv[1]).parent.name
exec(source)
# Validate mechanical and actuator dynamics against the ACTUAL future command
# sequence, rather than incorrectly comparing a held-command forecast with
# a trajectory on which the controller subsequently changes its commands.
rows=[]
velocity=rate+.01*acc
for h in [.10,.16,.22,.30,.40,.50]:
 steps=round(h/.02);N=q.shape[0]-steps
 integ=np.zeros((3,N));predtorque=actual[:,:N].copy();ok=valid[:N].copy()
 for k in range(steps):
  command=pending[:,k:k+N]
  alpha=np.exp(-.02/tau)
  integ+=(command-predtorque)*(.02-tau*(1-alpha))
  # Integral of torque minus torque at initial observation.
  integ+=(predtorque-actual[:,:N])*.02
  predtorque=command+(predtorque-command)*alpha
  ok &= (mode[k:k+N]==1)&(command[0]>10)
 pred=obs[:N,5]+h*(J[0]@velocity[:,:N])+(J[0]@G)@integ
 end=np.rint((q[:N,0]+h)/.002).astype(int)
 error=o[end,5]-pred
 tr=train[:N]&ok;te=test[:N]&ok
 # Also report a model with observed load acceleration drift. Do not fit
 # any coefficient to the failure window.
 for label,mask in [('train',tr),('test',te),('failure',failtest[:N]&ok)]:
  e=error[mask];rows.append(dict(horizon_s=h,split=label,count=len(e),max_abs_error=float(max(abs(e))),max_underestimate=float(max(e)),min_error=float(min(e))))
 sel=np.flatnonzero(tr|te)
 pd.DataFrame(dict(time_s=q[sel,0],horizon_s=h,train=tr[sel],test=te[sel],predicted_A_rpm=pred[sel],native_actual_A_rpm=o[end[sel],5],error_A_rpm=error[sel])).to_csv(B/(suffix+'_long_'+str(h)+'_points.csv'),index=False)
pd.DataFrame(rows).to_csv(B/('long_input_sequence_validation.csv' if suffix=='baseline' else suffix+'_long_input_sequence_validation.csv'),index=False)
print(pd.DataFrame(rows).to_string(index=False))
