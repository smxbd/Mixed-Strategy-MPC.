from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
import json
import h5py
import numpy as np
import pandas as pd
ROOT=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice')
BASE=ROOT/'ml_ems/results/motor_speed_stage2_20261026_001'


def main():
 z=zipfile.ZipFile(ROOT/'ml_ems/models/EMT_ML.slx');inventory=[]
 tags={'ne_ref','Te_ref','TA_ref','TB_ref','v_com','dv_act','stage','Fb_ref'}
 for name in z.namelist():
  if not name.startswith('simulink/systems/') or not name.endswith('.xml'):continue
  root=ET.fromstring(z.read(name))
  for b in root.findall('Block'):
   props={p.get('Name'):p.text for p in b.findall('.//P')}
   if props.get('GotoTag') in tags or b.get('SID') in ['22002','22008','22280','22199']:
    inventory.append(dict(system=name,sid=b.get('SID'),name=b.get('Name'),type=b.get('BlockType'),properties=props))
 (BASE/'control_interface_inventory.json').write_text(json.dumps(inventory,indent=2,ensure_ascii=False),encoding='utf8')
 with h5py.File(ROOT/'figure_outputs/two_controller_full_20261026_001/data/suburban400_Transformer.mat') as f:
  p=f['run/cfg/p'];s=lambda n:float(p[n][0,0]);factor=(1+s('kh'))/s('kh')*s('ic')/.377/s('rz')
  rows=[]
  for name,a,b in [('EVT1',np.array([s('a11'),s('b11')]),np.array([s('a12'),s('b12')])),('EVT2',np.array([s('a21'),s('b21')]),np.array([s('a22'),s('b22')])),('EVT1_L',np.array([s('a11_L'),s('b11_L')]),np.array([s('a12_L'),s('b12_L')]))]:
   for v in np.arange(0,120.0001,.1):
    lo=s('ne_min');hi=s('ne_max')
    for ai,bi in zip(a,b):
     if abs(ai)<1e-12:
      if abs(bi*factor*v)>6000:hi=-np.inf
     else:
      ends=(np.array([-6000,6000])-bi*factor*v)/ai;lo=max(lo,min(ends));hi=min(hi,max(ends))
    rows.append(dict(mode=name,vehicle_kmh=v,engine_lower_rpm=lo,engine_upper_rpm=hi,feasible=lo<=hi,mode_control_exposed=False))
  pd.DataFrame(rows).to_csv(BASE/'all_mode_static_domains.csv',index=False)
  t=f['run/physical/time'][()].ravel();o=f['run/physical/signals/values'][()].T
  c=f['run/cycle'];ct=c['time'][()].ravel();cv=c['v_ref'][()].ravel()
  wanted=np.interp(t,ct,cv);filtered=np.zeros(len(t));delta=np.diff(t);alpha=np.exp(-delta)
  for i in range(len(delta)):
   slope=(wanted[i+1]-wanted[i])/delta[i];filtered[i+1]=alpha[i]*filtered[i]+(1-alpha[i])*wanted[i]+slope*(delta[i]-1+alpha[i])
  err=float(np.max(abs(filtered-o[:,0])))
  (BASE/'requested_reference_reconstruction.json').write_text(json.dumps(dict(max_abs_error_kmh=err,comparison='original requested cycle plus original 1-second driver prefilter versus baseline physical reference',statistics_contract_unchanged=err<1e-6),indent=2),encoding='utf8')
  assert err<1e-6, 'Do not use a changed tracking target'
 print('Architecture inventory and all-mode domains saved; original reference reconstruction error',err)


if __name__=='__main__':main()
