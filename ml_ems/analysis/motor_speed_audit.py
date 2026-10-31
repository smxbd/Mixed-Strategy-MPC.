"""Audit native physical samples; controller values are causal ZOH annotations.

Never resamples/deletes physical samples. Durations use native sample support,
clipped at the simulation end. Logged controller annotations include their age.
"""
import argparse
import hashlib
import json
from pathlib import Path
import h5py
import numpy as np
import pandas as pd


def scalar(group, key):
    return float(group[key][()].reshape(-1)[0])


def index_at(t, query):
    return np.maximum(0, np.searchsorted(t, query + 1e-10, side='right') - 1)


def intervals(t, mask):
    edges = np.diff(np.r_[False, mask, False].astype(int))
    starts, ends = np.flatnonzero(edges == 1), np.flatnonzero(edges == -1) - 1
    return list(zip(starts, ends))


def audit(path, output, label):
    with h5py.File(path) as f:
        r = f['run']; p = r['cfg']['p']
        t = r['physical']['time'][()].reshape(-1)
        o = r['physical']['signals']['values'][()].T
        assert np.all(np.diff(t) > 0) and np.isfinite(o).all()
        assert o.shape[1] >= 21, 'Direct physical engine speed required'
        support = np.diff(t, append=t[-1])
        ct = r['time'][()].reshape(-1); q = r['trace'][()].T
        ix = index_at(ct, t); x = q[ix, :19]
        nout = o[:, 1]*(1+scalar(p,'kh'))/scalar(p,'kh')*scalar(p,'ic')/.377/scalar(p,'rz')
        high = x[:, 3] == 3; low = x[:, 3] == 1
        coeff_e = np.array([[scalar(p,'a11'),scalar(p,'b11')], [scalar(p,'a21'),scalar(p,'b21')]])[high.astype(int)]
        coeff_o = np.array([[scalar(p,'a12'),scalar(p,'b12')], [scalar(p,'a22'),scalar(p,'b22')]])[high.astype(int)]
        lo = np.full(len(t), scalar(p,'ne_min')); hi = np.full(len(t), scalar(p,'ne_max'))
        for m in range(2):
            a = coeff_e[:,m]; b = coeff_o[:,m]*nout; lim = scalar(p,'nA_max' if m == 0 else 'nB_max')
            active = abs(a)>1e-12
            lower = np.divide(-lim-b,a,out=np.full_like(a,-np.inf),where=active)
            upper = np.divide(lim-b,a,out=np.full_like(a,np.inf),where=active)
            lo = np.maximum(lo,np.where(active,np.minimum(lower,upper),-np.inf))
            hi = np.minimum(hi,np.where(active,np.maximum(lower,upper),np.inf))
            hi[~active & (abs(b)>lim)] = -np.inf
        known = high | low
        base = pd.DataFrame(dict(time_s=t, motorA_rpm=o[:,5], motorB_rpm=o[:,6], motorA_Nm=o[:,17], motorB_Nm=o[:,18], engine_rpm=o[:,20], engine_Nm=o[:,16], speed_kmh=o[:,1], reference_kmh=o[:,0], current_A=o[:,4], SOC_percent=o[:,2], stage_logged=x[:,3], range_logged=x[:,2], controller_annotation_age_s=t-ct[ix], speed_interval_lower_rpm=lo, speed_interval_upper_rpm=hi, static_kinematic_infeasible=known & (lo>hi), kinematics_mode_known=known))
        if 'governance' in r:
            base['safe_reference_kmh']=o[:,0]
            base['reference_kmh']=r['governance']['requested_reference_kmh'][()].reshape(-1)
        runtime=r['runtime']
        if 'execution_commands' in runtime:
            commands=runtime['execution_commands'][()].T; command_time=commands[:,0]; issued=commands[:,10:14]; raw=commands[:,6:10]
        else:
            command_time=ct;issued=q[:,43:47];raw=q[:,39:43]
        ci=index_at(command_time,t);pi=index_at(command_time,t-.02)
        base['issued_command_age_s']=t-command_time[ci]
        base['assumed_transport_delay_s']=.02
        base['pending_command_age_s']=t-command_time[pi]
        for j,name in enumerate(('ne_ref_rpm','Te_ref_Nm','TA_ref_Nm','TB_ref_Nm')):
            base['raw_'+name]=raw[ci,j];base['issued_'+name]=issued[ci,j];base['delayed_assumed_'+name]=issued[pi,j]
        base['fallback_logged']=q[ix,48];base['infeasible_logged']=q[ix,50]
        if 'diagnostics' in runtime:
            d=runtime['diagnostics'][()].T;di=index_at(d[:,0],t)
            base['command_residual_logged']=d[di,2];base['state_residual_logged']=d[di,3]
        summary={k:float(v[0,0]) for k,v in r['metrics'].items() if getattr(v,'shape',None)==(1,1) and v.dtype.kind in 'fiu'}
        summary['source']=str(path);summary['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        summary['native_step_s']=float(np.median(np.diff(t)))
        summary['static_infeasible_samples']=int(np.sum(known & (lo>hi)))
        summary['mode_unknown_samples']=int(np.sum(~known))
        summary['static_infeasible_even_4500rpm_samples']=int(np.sum(known & (lo>4500)))
        summary['motors']={}
        for m,name in enumerate(('A','B')):
            speed=o[:,5+m]; limit=scalar(p,'n'+name+'_max');mask=abs(speed)>limit
            points=base.loc[mask].copy();points['excess_rpm']=abs(speed[mask])-limit
            points.to_csv(output/(label+'_motor'+name+'_points.csv'),index=False)
            rows=[]
            for start,end in intervals(t,mask):
                peak=start+int(np.argmax(abs(speed[start:end+1])))
                rows.append(dict(start_s=t[start],end_s=t[end],right_edge_s=t[min(end+1,len(t)-1)],span_s=t[end]-t[start],duration_s=float(support[start:end+1].sum()),samples=end-start+1,max_abs_rpm=abs(speed[peak]),peak_s=t[peak],static_infeasible_samples=int(np.sum(known[start:end+1] & (lo[start:end+1]>hi[start:end+1])))))
            pd.DataFrame(rows,columns=['start_s','end_s','right_edge_s','span_s','duration_s','samples','max_abs_rpm','peak_s','static_infeasible_samples']).to_csv(output/(label+'_motor'+name+'_segments.csv'),index=False)
            predicted=coeff_e[:,m]*o[:,20]+coeff_o[:,m]*nout
            error=abs(speed-predicted)
            summary['motors'][name]=dict(samples=int(mask.sum()),max_abs_rpm=float(abs(speed).max()),segments=len(rows),first_s=float(t[np.flatnonzero(mask)[0]]) if mask.any() else None,total_duration_s=float(support[mask].sum()),max_duration_s=max([v['duration_s'] for v in rows],default=0),static_infeasible_overspeed_samples=int(np.sum(mask & known & (lo>hi))),kinematic_residual_known_max_rpm=float(error[known].max()),kinematic_residual_known_median_rpm=float(np.median(error[known])))
            assert summary['motors'][name]['samples']==int(summary['motor'+name+'_overspeed_samples'])
        summary['command_actual_max_abs']={name:float(np.max(abs(issued[pi,j]-o[:,col]))) for j,col,name in ((0,20,'engine_rpm'),(1,16,'engine_Nm'),(2,17,'motorA_Nm'),(3,18,'motorB_Nm'))}
        summary['safety_budget_s']=.020
        if 'wrapper_times' in runtime:
            w=runtime['wrapper_times'][()].T; dec=np.isclose(np.mod(w[:,0],.1),0,atol=1e-7)|np.isclose(np.mod(w[:,0],.1),.1,atol=1e-7)
            summary['safety_wrapper_max_s']=float(w[~dec,1].max()) if (~dec).any() else 0
            summary['safety_wrapper_over_budget']=int(np.sum(w[~dec,1]>.020))
        return summary


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--data',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--phase',default='before');a=ap.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    result={}
    for cycle in ('stress300','suburban400'):
        for controller in ('Existing','Transformer'):
            path=a.data/(cycle+'_'+controller+'.mat')
            if not path.exists() and controller=='Transformer':
                candidates=list(a.data.glob(cycle+'_m7_*/run.mat'))
                assert len(candidates)<=1, 'Ambiguous fresh run selection'
                if candidates:path=candidates[0]
            if path.exists():
                key=cycle+'_'+controller;result[key]=audit(path,a.output,a.phase+'_'+key)
                print(key,json.dumps(result[key]['motors']),flush=True)
    (a.output/(a.phase+'_audit.json')).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    pd.DataFrame([dict(case=k,**{m:v for m,v in s.items() if isinstance(v,(float,int))}) for k,s in result.items()]).to_csv(a.output/(a.phase+'_all_metrics.csv'),index=False)


if __name__=='__main__':
    main()
