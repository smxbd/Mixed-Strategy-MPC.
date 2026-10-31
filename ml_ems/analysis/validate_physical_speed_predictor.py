"""Validate a torque-driven rotor model; never trains or deploys a controller.

The unmeasured generalized reaction is observed from a preceding interval.
Its future constancy is tested, not asserted. Every failing endpoint is saved.
"""
from pathlib import Path
import json
import h5py
import numpy as np
import pandas as pd

ROOT=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice')
BASE=ROOT/'ml_ems/results/motor_speed_stage2_20261026_001'


def main():
 status=json.loads((ROOT/'ml_ems/results/motor_speed_audit_20261026_001/validation_status.json').read_text())
 summaries=[]
 for case in status['cases']:
  with h5py.File(Path(case['folder'])/'run.mat') as f:
   r=f['run'];p=r['cfg/p'];s=lambda name:float(p[name][0,0])
   t=r['physical/time'][()].ravel();o=r['physical/signals/values'][()].T
   qt=r['time'][()].ravel();x=r['trace'][()].T[:,:19]
   cmd=r['runtime/execution_commands'][()].T
   tick=np.arange(10,len(t)-111,10) # Actual 0.02 s callback grid, no reinterpolation.
   indices=np.maximum(0,np.searchsorted(qt,t[tick]+1e-10,side='right')-1)
   mode=x[indices,3];ranges=x[indices,2]
   validmode=(mode==1)|(mode==3)
   ne=o[tick,20];road=o[:,1]*(1+s('kh'))/s('kh')*s('ic')/.377/s('rz')
   nr=road[tick];dne=(ne-o[tick-10,20])/.02;dno=(nr-road[tick-10])/.02
   a=np.where(mode==3,s('a21'),s('a11'));b=np.where(mode==3,s('b21'),s('b11'))
   ar=np.where(mode==3,s('a22'),s('a12'));br=np.where(mode==3,s('b22'),s('b12'))
   # Known rotor inertias in original model; omitted shafts/friction enter
   # the observed reaction. No empirically selected input gain is introduced.
   inertia=s('Je')+s('JA')*a*a+s('JB')*b*b
   cross=s('JA')*a*ar+s('JB')*b*br
   engineFactor=s('Y_engine')*(1103-180)/1103
   actual=o[tick][:,[16,17,18]]
   ci=np.maximum(0,np.searchsorted(cmd[:,0],t[tick]+1e-10,side='right')-1)
   pi=np.maximum(0,np.searchsorted(cmd[:,0],t[tick]-.02+1e-10,side='right')-1)
   issued=cmd[ci,11:14];pending=cmd[pi,11:14]
   # These are exposed references, NOT claimed measurements of post-PID input.
   coeff=np.column_stack((np.full(len(tick),engineFactor),a,b))
   torque=coeff*actual
   reaction=torque.sum(axis=1)-inertia*dne*np.pi/30-cross*dno*np.pi/30
   tau=np.array([s('Ts_e'),s('TS_A'),s('TS_B')])
   # A preceding, disjoint stable interval establishes a *candidate* bound.
   train=(t[tick]>=40)&(t[tick]<49)&validmode&(mode==3)
   test=np.zeros(len(tick),bool)
   for left,right in [(51.268,56.394),(90.352,104.468),(143.368,152.434),(262.382,272.492)]:
    test|=(t[tick]>=left)&(t[tick]<=right)
   if case['cycle']=='suburban400':
    train=(t[tick]>=180)&(t[tick]<230)&validmode&(mode==3)
    test=(t[tick]>=250)&(t[tick]<=355)
   rows=[];errorstats=[]
   for h in (.02,.04,.12,.22):
    steps=int(round(h/.002));future=tick+steps
    kernel=h-tau*(1-np.exp(-h/tau))
    after=max(0,h-.02);kernelAfter=after-tau*(1-np.exp(-after/tau))
    integral=actual*h+(pending-actual)*kernel+(issued-pending)*kernelAfter
    predictedNe=ne+30/np.pi/inertia*((coeff*integral).sum(axis=1)-reaction*h)-cross/inertia*(h*dno)
    predictedRoad=nr+h*dno
    predA=a*predictedNe+ar*predictedRoad;predB=b*predictedNe+br*predictedRoad
    # Preserve current measured kinematic discrepancy in prediction.
    predA+=o[tick,5]-a*ne-ar*nr;predB+=o[tick,6]-b*ne-br*nr
    errA=o[future,5]-predA;errB=o[future,6]-predB
    trainBound=max(np.max(abs(errA[train])),np.max(abs(errB[train]))) if train.any() else np.nan
    finite=validmode&test
    row=dict(cycle=case['cycle'],horizon_s=h,training_bound_rpm=float(trainBound),independent_samples=int(finite.sum()),independent_max_error_A_rpm=float(abs(errA[finite]).max()),independent_max_error_B_rpm=float(abs(errB[finite]).max()),independent_bound_failures=int(np.sum(finite&((abs(errA)>trainBound)|(abs(errB)>trainBound)))))
    errorstats.append(row);summaries.append(row)
    selected=np.flatnonzero(train|test)
    for i in selected:
     rows.append(dict(observation_s=t[tick[i]],endpoint_s=t[future[i]],horizon_s=h,training=bool(train[i]),independent_test=bool(test[i]),mode=mode[i],range=ranges[i],mode_supported=bool(validmode[i]),actual_A_rpm=o[future[i],5],actual_B_rpm=o[future[i],6],predicted_A_rpm=predA[i],predicted_B_rpm=predB[i],error_A_rpm=errA[i],error_B_rpm=errB[i],candidate_bound_rpm=trainBound,bound_failed=bool(abs(errA[i])>trainBound or abs(errB[i])>trainBound),reaction_Nm=reaction[i],known_rotor_inertia_kgm2=inertia[i]))
   pd.DataFrame(rows).to_csv(BASE/(case['cycle']+'_physical_predictor_validation.csv'),index=False)
   print(case['cycle'],json.dumps(errorstats),flush=True)
 pd.DataFrame(summaries).to_csv(BASE/'physical_predictor_summary.csv',index=False)
 (BASE/'physical_predictor_gate.json').write_text(json.dumps(dict(deployable=False,reason='Unmeasured generalized reaction, post-PID commands and clutch states have no verified future bounds; independent bound failures are retained.',data=summaries),indent=2),encoding='utf8')


if __name__=='__main__':main()
