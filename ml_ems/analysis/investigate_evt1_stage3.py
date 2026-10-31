from pathlib import Path
import json
import h5py
import numpy as np
import pandas as pd

R=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice')
B=R/'ml_ems/results/motor_speed_stage3_20261026_001';B.mkdir(exist_ok=True)
status=json.loads((R/'ml_ems/results/motor_speed_stage2_20261026_001/full_regression/status.json').read_text(encoding='utf8'))
case=status['cases'][0]
with h5py.File(Path(case['folder'])/'run.mat') as f:
 r=f['run'];p=r['cfg/p'];get=lambda k:float(p[k][0,0]);q=r['runtime/safety_inputs'][()].T
 t=r['physical/time'][()].ravel();o=r['physical/signals/values'][()].T;obs=q[:,20:40]
 ne=np.divide(9549*obs[:,12],obs[:,16],out=q[:,5].copy(),where=abs(obs[:,16])>1e-6)
 no=obs[:,1]*(1+get('kh'))/get('kh')*get('ic')/.377/get('rz');v=np.array([ne,no])
 rate=np.column_stack((np.zeros(2),np.diff(v,axis=1)/.02));acc=np.column_stack((np.zeros(2),np.diff(rate,axis=1)/.02))
 mode=q[:,4];valid=(mode==1)&np.r_[False,mode[:-1]==1]&np.r_[False,False,mode[:-2]==1]&(q[:,53]>10)&(abs(obs[:,16])>1e-6)
 train=valid&(q[:,0]>=141)&(q[:,0]<160)
 test=valid&(((q[:,0]>=161)&(q[:,0]<177.5))|((q[:,0]>=202.6)&(q[:,0]<222.5))|((q[:,0]>=2)&(q[:,0]<9)))
 failtest=valid&(q[:,0]>=168)&(q[:,0]<=172)
 a=np.array([get('a11'),get('b11')]);b=np.array([get('a12'),get('b12')]);J=np.column_stack((a,b))
 I=get('Je')+get('JA')*a[0]**2+get('JB')*a[1]**2
 cross=get('JA')*a[0]*b[0]+get('JB')*a[1]*b[1]
 ratio=(1+get('kh'))/get('kh')*get('ic')
 roadI=get('mass')*get('rz')**2/ratio**2+get('JA')*b[0]**2+get('JB')*b[1]**2
 M=np.array([[I,cross],[cross,roadI]])
 factor=get('Y_engine')*(1103-180)/1103
 G=30/np.pi*np.linalg.solve(M,np.array([[factor,a[0],a[1]],[0,b[0],b[1]]]))
 scalar=30/np.pi/I*np.array([factor,a[0],a[1]])
 actual=obs[:,[16,17,18]].T;pending=q[:,53:56].T;issued=q[:,49:52].T
 tau=np.array([get('Ts_e'),get('TS_A'),get('TS_B')])[:,None]
 torqueRate=(pending-actual)/tau
 rows=[]
 for h in [.02,.04,.06,.10,.16,.22]:
  F=h-tau*(1-np.exp(-h/tau));post=max(0,h-.02);Fa=post-tau*(1-np.exp(-post/tau))
  integ=(pending-actual)*F+(issued-pending)*Fa
  models={
   'scalar_old':np.array([ne+h*rate[0]+scalar@integ,no+h*rate[1]]),
   'scalar_centered':np.array([ne+h*(rate[0]+.01*acc[0])+scalar@integ,no+h*(rate[1]+.01*acc[1])+.5*h*h*acc[1]]),
   'coupled_centered':v+h*(rate+.01*acc)+G@integ,
   'coupled_force_rate':v+h*(rate+.01*acc)+G@integ+.5*h*h*(acc-G@torqueRate)
  }
  end=np.minimum(len(t)-1,np.rint((q[:,0]+h)/.002).astype(int))
  for name,pred in models.items():
   speeds=J@pred+(obs[:,5:7].T-J@v);error=o[end,5]-speeds[0]
   rows.append(dict(model=name,horizon_s=h,train_max_A=float(max(abs(error[train]))),test_max_A=float(max(abs(error[test]))),failure_window_max_A=float(max(abs(error[failtest]))),test_failures=int(sum(abs(error[test])>max(abs(error[train]))))))
   if name=='coupled_centered':
    sel=np.flatnonzero(train|test)
    pd.DataFrame(dict(time_s=q[sel,0],horizon_s=h,train=train[sel],test=test[sel],predicted_A=speeds[0,sel],actual_A=o[end[sel],5],error_A=error[sel])).to_csv(B/('coupled_'+str(h)+'_points.csv'),index=False)
 pd.DataFrame(rows).to_csv(B/'prediction_variants.csv',index=False)
 print(pd.DataFrame(rows).to_string(index=False))
 print('M',M,'G',G)
