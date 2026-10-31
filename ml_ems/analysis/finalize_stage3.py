from pathlib import Path
import json,hashlib,subprocess,difflib,importlib.util,re
import numpy as np,pandas as pd,h5py
R=Path.cwd();B=R/'ml_ems/results/motor_speed_stage3_20261026_001';OLD=R/'ml_ems/results/motor_speed_stage2_20261026_001'
spec=importlib.util.spec_from_file_location('audit',R/'ml_ems/analysis/motor_speed_audit.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
def status(p):return json.loads(p.read_text(encoding='utf8'))
def git(*a):return subprocess.run([r'D:\GIT\Git\cmd\git.exe','-C',str(R),*a],capture_output=True).stdout.decode('utf8',errors='replace')
def timing(r,label):
 w=r['runtime/wrapper_times'][()].T;d=r['runtime/diagnostics'][()].T;assert np.array_equal(w[:,0],d[:,0]);rows=[]
 for kind,sel,limit in [('safety',d[:,1]==0,.02),('decision',d[:,1]!=0,.1),('all_wrappers',np.ones(len(d),bool),.02)]:
  v=w[sel,1];rows.append(dict(case=label,kind=kind,count=len(v),max_ms=1000*max(v),P95_ms=1000*np.percentile(v,95),P99_ms=1000*np.percentile(v,99),over20ms=int(sum(v>.02)),over_assigned_budget=int(sum(v>limit))))
 return rows
def baseline_sources():
 lines=(OLD/'all_changes.patch').read_text(encoding='utf8').splitlines(keepends=True);result={};i=0
 while i<len(lines):
  if not lines[i].startswith('diff --git '):i+=1;continue
  path=lines[i].split(' b/',1)[1].strip();i+=1;chunk=[]
  while i<len(lines) and not lines[i].startswith('diff --git '):chunk.append(lines[i]);i+=1
  original=git('show','HEAD:'+path).splitlines(keepends=True);out=[];cursor=0;j=0
  while j<len(chunk):
   m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',chunk[j])
   if not m:j+=1;continue
   start=max(0,int(m[1])-1);out.extend(original[cursor:start]);cursor=start;j+=1
   while j<len(chunk) and not chunk[j].startswith('@@ '):
    z=chunk[j]
    if z.startswith(' '):out.append(z[1:]);cursor+=1
    elif z.startswith('-'):cursor+=1
    elif z.startswith('+'):out.append(z[1:])
    j+=1
  out.extend(original[cursor:]);result[path]=''.join(out)
 return result
def main():
 s=status(B/'round4/status.json');assert s['completed'];before=status(OLD/'full_regression/status.json');failed=status(B/'round1/status.json');failed2=status(B/'round2/status.json');failed3=status(B/'round3b/status.json')
 out=B/'native_statistics';out.mkdir(exist_ok=True);summaries={};rows=[];times=[];energy=[];accept={};identical={}
 allcases=[('before',c) for c in before['cases']]+[('failed_round1',c) for c in failed['cases']]+[('failed_round2',c) for c in failed2['cases']]+[('failed_round3b',c) for c in failed3['cases']]+[('after',c) for c in s['cases']]
 for phase,c in allcases:
  cycle=c['cycle'];label=phase+'_'+cycle;path=Path(c['folder'])/'run.mat';a=audit.audit(path,out,label);a['engine_max_positive_excess_Nm']=max(0,a['engine_max_excess_Nm']);summaries[label]=a
  with h5py.File(path) as f:
   r=f['run'];t=r['physical/time'][()].ravel();o=r['physical/signals/values'][()].T;q=r['runtime/safety_inputs'][()].T
   assert len(t)==(150001 if cycle=='stress300' else 200001);assert np.max(abs(np.diff(t)-.002))<1e-9
   times+=timing(r,label)
   # Native point annotations use the exact causal 20 ms input buffer.
   for motor in ['A','B']:
    point=out/(label+'_motor'+motor+'_points.csv');df=pd.read_csv(point)
    if len(df):
     ix=audit.index_at(q[:,0],df.time_s.to_numpy());df['stage_exact_callback']=q[ix,4];df['range_exact_callback']=q[ix,3];df['exact_callback_age_s']=df.time_s.to_numpy()-q[ix,0]
     pt=r['runtime/projection_times'][()].T;df['fallback_exact_callback']=(pt[ix,2]>0);df['command_residual_exact']=r['runtime/diagnostics'][()].T[ix,2];df.to_csv(point,index=False)
   if phase=='after':
    safety=[z for z in times if z['case']==label and z['kind']=='safety'][0]
    accept[cycle]=dict(motorA_pass=a['motors']['A']['samples']==0,motorB_pass=a['motors']['B']['samples']==0,engine_gt1Nm_pass=a['engine_violation_samples']==0,safety_20ms_pass=safety['over20ms']==0,current_samples=a['current_violation_samples'],voltage_samples=a['voltage_violation_samples'],soc_samples=a['soc_violation_samples'])
    accept[cycle]['this_round_pass']=all(accept[cycle][k] for k in ['motorA_pass','motorB_pass','engine_gt1Nm_pass','safety_20ms_pass'])
    oldc=next(z for z in before['cases'] if z['cycle']==cycle)
    with h5py.File(Path(oldc['folder'])/'run.mat') as oldf:
     oo=oldf['run/physical/signals/values'][()].T;diff=np.max(abs(o-oo),axis=0);identical[cycle]=dict(physical_bit_identical=bool(np.array_equal(o,oo)),max_abs_per_channel=diff.tolist(),first_change_s=float(t[np.flatnonzero(np.any(o!=oo,axis=1))[0]]) if np.any(o!=oo) else None)
    original=R/('figure_outputs/two_controller_full_20261026_001/data/'+cycle+'_Existing.mat')
    with h5py.File(original) as ef:
     er=ef['run'];em=er['metrics'];fuel=float(em['fuel_L'][0,0]);soc=float(em['delta_SOC_percent'][0,0]);dist=float(em['distance_km'][0,0])
    b=summaries['before_'+cycle]
    for state,v in [('Existing_historical',dict(fuel_L=fuel,delta_SOC_percent=soc,distance_km=dist)),('before',b),('after',a)]:
     energy.append(dict(cycle=cycle,state=state,fuel_L=v['fuel_L'],delta_SOC_pp=v['delta_SOC_percent'],distance_km=v['distance_km'],fuel_change_vs_Existing_pct=100*(v['fuel_L']/fuel-1),SOC_change_vs_Existing_pp=v['delta_SOC_percent']-soc,fuel_change_vs_before_pct=100*(v['fuel_L']/b['fuel_L']-1)))
 for c in s['cases']:
  cycle=c['cycle'];a=summaries['before_'+cycle];b=summaries['after_'+cycle]
  for key in sorted(set(a)&set(b)):
   if isinstance(a[key],(int,float)) and isinstance(b[key],(int,float)):rows.append(dict(cycle=cycle,metric=key,before=a[key],after=b[key],delta=b[key]-a[key]))
  for motor in ['A','B']:
   for key in ['samples','max_abs_rpm','max_duration_s','total_duration_s','segments']:
    x=a['motors'][motor][key];y=b['motors'][motor][key];rows.append(dict(cycle=cycle,metric='motor'+motor+'_'+key,before=x,after=y,delta=y-x))
  for key in a['command_actual_max_abs']:
   x=a['command_actual_max_abs'][key];y=b['command_actual_max_abs'][key];rows.append(dict(cycle=cycle,metric='command_actual_max_abs_'+key,before=x,after=y,delta=y-x))
 pd.DataFrame(rows).to_csv(B/'complete_before_after_metrics.csv',index=False);pd.DataFrame(times).to_csv(B/'all_callback_timing.csv',index=False);pd.DataFrame(energy).to_csv(B/'energy_comparison.csv',index=False)
 for name,value in [('before_after_audit',summaries),('acceptance',accept),('trajectory_comparison',identical)]: (B/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf8')
 full=git('diff','--');paths=git('ls-files','--others','--exclude-standard').splitlines()
 for path in paths:full+=git('diff','--no-index','--','NUL',path)
 (B/'all_changes.patch').write_text(full,encoding='utf8');base=baseline_sources();delta=''
 for path in sorted(set(git('diff','--name-only').splitlines()+paths)):
  current=(R/path).read_text(encoding='utf-8-sig');previous=base.get(path,git('show','HEAD:'+path))
  delta+=''.join(difflib.unified_diff(previous.splitlines(keepends=True),current.splitlines(keepends=True),fromfile='before/'+path,tofile='after/'+path))
 (B/'this_round_changes.patch').write_text(delta,encoding='utf8')
 log=(B/'round4/validation.log').read_text(encoding='utf8',errors='replace')
 for cycle in ['stress300','suburban400']:
  start=log.index('BEGIN_FULL '+cycle);end=log.index('END_FULL '+cycle,start);end=log.find('\n',end);(B/(cycle+'_full_simulation.log')).write_text(log[start:end if end>=0 else None]+'\n',encoding='utf8')
 print(json.dumps(dict(acceptance=accept,trajectories=identical),indent=2));print(pd.DataFrame(energy).to_string(index=False));print(pd.DataFrame(times).to_string(index=False))
if __name__=='__main__':main()
