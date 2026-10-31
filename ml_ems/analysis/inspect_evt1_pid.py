from pathlib import Path
import h5py,json,numpy as np,pandas as pd
R=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice');B=R/'ml_ems/results/motor_speed_stage3_20261026_001'
s=json.loads((R/'ml_ems/results/motor_speed_stage2_20261026_001/full_regression/status.json').read_text(encoding='utf8'))
with h5py.File(Path(s['cases'][0]['folder'])/'run.mat') as f:
 q=f['run/runtime/safety_inputs'][()].T;o=q[:,20:40];alpha=np.exp(-.02/.1)
 equivalent=np.r_[np.nan,(o[1:,16]-alpha*o[:-1,16])/(1-alpha)]
 lagged=np.r_[np.nan,q[:-1,53]]
 df=pd.DataFrame(dict(time_s=q[:,0],stage=q[:,4],motorA_rpm=o[:,5],engine_Nm=o[:,16],issued_Te=q[:,49],pending_Te=q[:,53],previous_applied_Te=lagged,equivalent_input_Nm=equivalent,bias_Nm=equivalent-lagged,raw_TA=q[:,46],issued_TA=q[:,50],actual_TA=o[:,17]))
 df=df[(df.time_s>=167)&(df.time_s<=172)];df.to_csv(B/'before_evt1_torque_chain.csv',index=False)
 print(df[(df.pending_Te<=10)|(df.bias_Nm>200)].to_string(index=False))
