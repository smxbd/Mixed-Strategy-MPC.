from pathlib import Path
import json
import h5py
import numpy as np
import pandas as pd
R=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice')
B=R/'ml_ems/results/motor_speed_stage2_20261026_001/evt1_bounds';B.mkdir(exist_ok=True)
status=json.loads((B.parent/'full_regression/status.json').read_text());rows=[];bounds={}
for case in status['cases']:
 with h5py.File(Path(case['folder'])/'run.mat') as f:
  r=f['run'];p=r['cfg/p'];get=lambda k:float(p[k][0,0]);q=r['runtime/safety_inputs'][()].T
  t=r['physical/time'][()].ravel();o=r['physical/signals/values'][()].T
  obs=q[:,20:40];ne=np.divide(9549*obs[:,12],obs[:,16],out=q[:,5].copy(),where=abs(obs[:,16])>1e-6)
  no=obs[:,1]*(1+get('kh'))/get('kh')*get('ic')/.377/get('rz')
  dne=np.r_[0,np.diff(ne)/.02];dno=np.r_[0,np.diff(no)/.02]
  mode=q[:,4];valid=(mode==1)&np.r_[False,mode[:-1]==1]&(q[:,53]>10)&(abs(obs[:,16])>1e-6)
  if case['cycle']=='stress300':train=valid&(q[:,0]>=141)&(q[:,0]<160);test=valid&(((q[:,0]>=161)&(q[:,0]<177.5))|((q[:,0]>=202.6)&(q[:,0]<222.5))|((q[:,0]>=2)&(q[:,0]<9)))
  else:train=valid&(q[:,0]>=2)&(q[:,0]<10);test=valid&(((q[:,0]>=10)&(q[:,0]<18.2))|((q[:,0]>=387)&(q[:,0]<399.5)))
  assert sum(train)>100 and sum(test)>100
  a=np.array([get('a11'),get('b11')]);b=np.array([get('a12'),get('b12')])
  I=get('Je')+get('JA')*a[0]**2+get('JB')*a[1]**2
  coeff=30/np.pi/I*np.r_[get('Y_engine')*(1103-180)/1103,a]
  actual=obs[:,[16,17,18]];pending=q[:,53:56];issued=q[:,49:52]
  tau=np.array([get('Ts_e'),get('TS_A'),get('TS_B')]);all_bounds=[]
  for h in [.02,.04,.12,.22]:
   kernel=h-tau*(1-np.exp(-h/tau));after=max(0,h-.02);ka=after-tau*(1-np.exp(-after/tau))
   n=ne+h*dne+np.sum(coeff*((pending-actual)*kernel+(issued-pending)*ka),axis=1)
   pred=a[:,None]*n+b[:,None]*(no+h*dno)+(obs[:,5:7].T-a[:,None]*ne-b[:,None]*no)
   ix=np.rint((q[:,0]+h)/.002).astype(int);available=ix<len(t);ix=np.minimum(ix,len(t)-1)
   error=o[ix,5:7].T-pred
   bound=np.max(abs(error[:,train&available]),axis=1);maxTest=np.max(abs(error[:,test&available]),axis=1)
   row=dict(cycle=case['cycle'],horizon_s=h,training_A_rpm=float(bound[0]),training_B_rpm=float(bound[1]),validation_A_rpm=float(maxTest[0]),validation_B_rpm=float(maxTest[1]),training_samples=int(sum(train&available)),validation_samples=int(sum(test&available)),bound_failures=int(np.sum((abs(error)>bound[:,None])[:,test&available])))
   rows.append(row);all_bounds.append(bound.tolist())
   selected=np.flatnonzero((train|test)&available)
   pd.DataFrame(dict(time_s=q[selected,0],horizon_s=h,training=train[selected],validation=test[selected],error_A_rpm=error[0,selected],error_B_rpm=error[1,selected])).to_csv(B/(case['cycle']+'_'+str(h)+'_all_points.csv'),index=False)
  bounds[case['cycle']]=all_bounds
pd.DataFrame(rows).to_csv(B/'summary.csv',index=False)
(B/'bounds.json').write_text(json.dumps(bounds,indent=2))
print(pd.DataFrame(rows).to_string(index=False))
