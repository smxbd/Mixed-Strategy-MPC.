from pathlib import Path
import json
import hashlib
import subprocess
import difflib
import importlib.util
import h5py
import numpy as np
import pandas as pd

R=Path(r'C:\Users\LAPTOP1210\Desktop\Rming-advice\Rming-advice')
B=R/'ml_ems/results/motor_speed_stage2_20261026_001'
OLD=R/'ml_ems/results/motor_speed_audit_20261026_001'
GIT=r'D:\GIT\Git\cmd\git.exe'


def git(*args):
 return subprocess.run([GIT,'-C',str(R),*args],capture_output=True,check=False).stdout.decode('utf8',errors='replace')


def timing(label,r):
 w=r['runtime/wrapper_times'][()].T;d=r['runtime/diagnostics'][()].T
 assert np.array_equal(w[:,0],d[:,0]);rows=[]
 for kind,sel,limit in [('safety',d[:,1]==0,.02),('decision',d[:,1]!=0,.1),('all_wrappers',np.ones(len(d),bool),.02)]:
  v=w[sel,1];rows.append(dict(case=label,kind=kind,count=len(v),max_s=float(max(v)),P95_s=float(np.percentile(v,95)),P99_s=float(np.percentile(v,99)),over20ms=int(np.sum(v>.02)),over_assigned_budget=int(np.sum(v>limit))))
 return rows


def segments(t,mask):
 e=np.diff(np.r_[False,mask,False].astype(int));return list(zip(np.flatnonzero(e==1),np.flatnonzero(e==-1)-1))


def original_baseline_sources():
 # Reconstruct previous uncommitted baseline in memory from its saved diff.
 # No source backup or temporary checkout is created.
 lines=(OLD/'all_changes.patch').read_text().splitlines(keepends=True);result={};i=0
 while i<len(lines):
  if not lines[i].startswith('diff --git '):i+=1;continue
  path=lines[i].split(' b/',1)[1].strip();i+=1;chunk=[]
  while i<len(lines) and not lines[i].startswith('diff --git '):chunk.append(lines[i]);i+=1
  original=git('show','HEAD:'+path).splitlines(keepends=True);out=[];cursor=0;j=0
  import re
  while j<len(chunk):
   match=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',chunk[j])
   if not match:j+=1;continue
   start=max(0,int(match[1])-1);out.extend(original[cursor:start]);cursor=start;j+=1
   while j<len(chunk) and not chunk[j].startswith('@@ '):
    line=chunk[j]
    if line.startswith(' '):out.append(line[1:]);cursor+=1
    elif line.startswith('-'):cursor+=1
    elif line.startswith('+'):out.append(line[1:])
    j+=1
  out.extend(original[cursor:]);result[path]=''.join(out)
 return result


def main():
 status=json.loads((B/'full_regression/status.json').read_text());assert status['completed']
 oldstatus=json.loads((OLD/'validation_status.json').read_text());oldcases={c['cycle']:c for c in oldstatus['cases']}
 spec=importlib.util.spec_from_file_location('audit',R/'ml_ems/analysis/motor_speed_audit.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
 out=B/'native_statistics';out.mkdir(exist_ok=True);before={};after={};comparisons=[];times=[];other=[];accept={};gov=[]
 for case in status['cases']:
  cycle=case['cycle'];oldpath=Path(oldcases[cycle]['folder'])/'run.mat';newpath=Path(case['folder'])/'run.mat'
  before[cycle]=audit.audit(oldpath,out,'before_'+cycle)
  after[cycle]=audit.audit(newpath,out,'after_'+cycle)
  a=before[cycle];b=after[cycle]
  for group in (a,b):group['engine_max_positive_excess_Nm']=max(0,group['engine_max_excess_Nm'])
  for key in sorted(set(a)|set(b)):
   if isinstance(a.get(key),(int,float)) and isinstance(b.get(key),(int,float)):
    comparisons.append(dict(cycle=cycle,metric=key,before=a[key],after=b[key],delta=b[key]-a[key]))
  for m in ['A','B']:
   for key in ['samples','segments','total_duration_s','max_duration_s']:
    x=a['motors'][m][key];y=b['motors'][m][key];comparisons.append(dict(cycle=cycle,metric='motor'+m+'_'+key,before=x,after=y,delta=y-x))
  for key in a['command_actual_max_abs']:
   x=a['command_actual_max_abs'][key];y=b['command_actual_max_abs'][key]
   comparisons.append(dict(cycle=cycle,metric='command_actual_max_abs_'+key,before=x,after=y,delta=y-x))
  with h5py.File(oldpath) as old,h5py.File(newpath) as new:
   times+=timing('before_'+cycle,old['run']);times+=timing('after_'+cycle,new['run'])
   r=new['run'];t=r['physical/time'][()].ravel();o=r['physical/signals/values'][()].T
   assert len(t)==int(case['metrics']['physical_samples']) and abs(np.median(np.diff(t))-.002)<1e-10
   expected=150001 if cycle=='stress300' else 200001;assert len(t)==expected
   flags=dict(motorA=abs(o[:,5])>6000,motorB=abs(o[:,6])>6000,current=abs(o[:,4])>80,voltage=(o[:,3]<750)|(o[:,3]>1050),SOC=(o[:,2]<30)|(o[:,2]>80))
   physicalpeak=new['run/cfg/p/Te_max_map'][()].ravel();axis=new['run/cfg/p/ne_map'][()].ravel()
   excess=o[:,16]-np.interp(o[:,20],axis,physicalpeak);flags['engine_gt1Nm']=excess>1
   data=pd.DataFrame(dict(time_s=t,engine_rpm=o[:,20],engine_torque_Nm=o[:,16],engine_excess_Nm=excess,motorA_rpm=o[:,5],motorB_rpm=o[:,6],current_A=o[:,4],voltage_V=o[:,3],SOC_percent=o[:,2],speed_kmh=o[:,1]))
   for key,flag in flags.items():data[key+'_failed']=flag
   data.loc[np.logical_or.reduce(list(flags.values()))].to_csv(out/(cycle+'_all_hard_failure_points.csv'),index=False)
   for key,flag in flags.items():
    for start,end in segments(t,flag):
     other.append(dict(cycle=cycle,constraint=key,start_s=t[start],end_s=t[end],duration_s=t[min(end+1,len(t)-1)]-t[start],samples=end-start+1))
   safeTimes=[v for v in times if v['case']=='after_'+cycle and v['kind']=='safety'][0]
   accept[cycle]=dict(motor_speed_pass=not (flags['motorA']|flags['motorB']).any(),engine_gt1Nm_pass=not flags['engine_gt1Nm'].any(),current_pass=not flags['current'].any(),voltage_pass=not flags['voltage'].any(),SOC_pass=not flags['SOC'].any(),dedicated_safety_20ms_pass=safeTimes['over20ms']==0,overall_pass=False)
   if 'governance' in r:
    g=r['governance'];request=g['requested_reference_kmh'][()].ravel();safe=g['safe_reference_kmh'][()].ravel();reduction=request-safe;active=reduction>1e-6
    curve_t=g['time'][()].ravel();curve_request=g['requested_kmh'][()].ravel();curve_safe=g['safe_kmh'][()].ravel()
    pd.DataFrame(dict(time_s=t,original_requested_reference_kmh=request,safe_driver_reference_kmh=safe,reduction_kmh=reduction,actual_speed_kmh=o[:,1],active=active)).to_csv(B/'suburban400_governor_native.csv',index=False)
    for start,end in segments(t,active):gov.append(dict(start_s=t[start],end_s=t[end],duration_s=t[min(end+1,len(t)-1)]-t[start],maximum_reduction_kmh=float(max(reduction[start:end+1]))))
    assert abs(np.sqrt(np.mean((request-o[:,1])**2))-b['RMSE_kmh'])<1e-10
  print(cycle,accept[cycle],b['motors'],flush=True)
 pd.DataFrame(comparisons).to_csv(B/'complete_before_after_metrics.csv',index=False)
 pd.DataFrame(times).to_csv(B/'all_callback_timing.csv',index=False)
 pd.DataFrame(other).to_csv(B/'all_failure_segments.csv',index=False)
 pd.DataFrame(gov).to_csv(B/'governor_segments.csv',index=False)
 (B/'before_after_audit.json').write_text(json.dumps(dict(before=before,after=after),indent=2),encoding='utf8')
 (B/'acceptance.json').write_text(json.dumps(accept,indent=2),encoding='utf8')
 # Save complete source diff, including all new sources, plus this-stage delta.
 full=git('diff','--');paths=git('ls-files','--others','--exclude-standard').splitlines()
 for path in paths:full+=git('diff','--no-index','--','NUL',path)
 (B/'all_changes.patch').write_text(full,encoding='utf8')
 base=original_baseline_sources();changed=git('diff','--name-only').splitlines()+paths;delta=''
 for path in sorted(set(changed)):
  current=(R/path).read_text(encoding='utf-8-sig');previous=base.get(path,git('show','HEAD:'+path))
  delta+=''.join(difflib.unified_diff(previous.splitlines(keepends=True),current.splitlines(keepends=True),fromfile='before/'+path,tofile='after/'+path))
 (B/'this_stage_changes.patch').write_text(delta,encoding='utf8')
 log=(B/'full_regression/full_validation.log').read_text(encoding='utf8',errors='replace')
 for cycle in ['stress300','suburban400']:
  start=log.index('BEGIN_FULL '+cycle);end=log.index('END_FULL '+cycle,start);end=log.find('\n',end)
  (B/(cycle+'_full_simulation.log')).write_text(log[start:end if end!=-1 else None]+'\n',encoding='utf8')
 columns=['motorA_overspeed_samples','motorB_overspeed_samples','motorA_max_abs_rpm','motorB_max_abs_rpm','engine_violation_samples','engine_max_positive_excess_Nm','current_violation_samples','voltage_violation_samples','soc_violation_samples','RMSE_kmh','distance_km','reference_distance_km','distance_error_percent','fuel_L','fuel_L_100km','equivalent_fuel_L_100km','delta_SOC_percent','safety_infeasible_samples','safety_fallback_samples']
 lines=['# 电机转速越限：第二阶段控制修复与完整回归', '',
 '日期：2026-10-26。分支：电机转速越限。**整体验收未通过，当前代码为未验收候选。**', '',
 '本轮实际修复了执行逻辑与实时记录机制：suburban400 Motor A越限41966→0；stress300 Motor B越限20715→0；两工况28000次专用安全回调全部低于20 ms。完整stress300却新增305个EVT1 Motor A越限点；两工况仍有电流失败，suburban400原始请求跟踪显著退化。不能据此宣布整体修复成功。city200未运行。', '',
 '## 第一阶段：540 ms来源与预算修复', '',
 '最新基线0.060 s：wrapper=540.1764 ms，核心=539.2729 ms，投影=538.2973 ms。对原策略前3 s实际仿真剖析，复现0.060 s投影382.218 ms；第4次wrapper调用树首次触发optimoptions/createSolverOptions/findSubClasses/ver，选项创建累计311.202 ms。原预热在可行性早退之前退出，未触发选项构造。这是复现实验对冷路径的定位，并非对历史540 ms每一毫秒的事后逐函数测量。', '',
 '长轨迹另有持续开销：基线suburban安全核心最大10.5729 ms、wrapper最大37.4158 ms；wrapper减核心的P99为16.966 ms。ems_runtime通过containers.Map保存包含持续扩展数组、预测cell和富事件结构体的状态；改写状态触发大数组写时复制。原3 s剖析151回调调用execution_guard_limits 875次、interp1 23785次，说明同一回调重复计算大量相同边界。在线原本没有显式文件写入；首次optimoptions初始化会加载工具箱/选项类与文件信息。', '',
 '修复：QP选项初始化前移到所有早退之前，启动阶段显式预热求解器和不同模式/范围/不可行分支；同一回调以x/o/previous校验复用保护结果；EMSRealtimeLog使用预分配handle缓冲区，保存每个真实回调和四路原始/发出/待执行命令，不再在线追加富结构体。完整事件、误差和文件导出移到离线；reconstruct_safety_events可从全部回调重建保护详情。', '',
 'wrapper计时现包含record_wrapper记账和Map写回，结束时仅剩计时值自身存储的常数开销；没有排除启动点、超时点或首次求解。所有定长缓冲区耗尽均报错，不截断轨迹。QP四个功率符号区域、每区最多64次迭代，回退候选数有限；这不构成Windows任意调度环境下的WCET证明。', '',
 '|阶段/工况|专用安全回调数|最大ms|P95 ms|P99 ms|>20ms次数|','|---|---:|---:|---:|---:|---:|']
 for row in times:
  if row['kind']=='safety':lines.append(f"|{row['case']}|{row['count']}|{row['max_s']*1000:.4f}|{row['P95_s']*1000:.4f}|{row['P99_s']*1000:.4f}|{row['over20ms']}|")
 lines+=['', '**计时分类不混用：**专用安全回调指runtime.diagnostics的isDecision=0；每0.1 s的CEM决策回调另按项目原有100 ms预算报告。all_callback_timing.csv也列出全部wrapper按20 ms统计的次数，未把决策回调隐藏为零超时。如果将同一S-function内包括CEM决策在内的所有调用一律要求20 ms，则该更严格口径仍未通过；本报告只称专用安全回调20 ms通过。', '',
 '## 控制权限与本轮架构改变', '',
 '完整链：0.02 s S-function安全输出→22199 Rate Transition→四路参考→模式控制/PID/转矩分配→物理执行器前置饱和→Te的0.1 s、TA/TB的0.2 s滞后→机械惯量/传动→实测转速。ne_ref通过SID22280、Ts=0.5 s的PID生成sd_ne，参与原分配；它不是直接转速执行器。实际传动阶段及部分PID可覆盖高层参考，尤其启动/准备/换挡阶段。control_interface_inventory.json保留各From/Goto与关键块的SID/系统。', '',
 '原四路接口没有驾驶员速度治理、直接换挡或制动命令。本轮实现的最小额外执行接口，是通过SimulationInput将驾驶员查表SID22002的Table接入governed_v_cyc；只改本次运行的控制输入，原始EMT.mdl、EMT_ML.slx二进制与物理子系统均未写回。未假定已有换挡/制动权限，也未改传动比。', '',
 '联合投影在已验证的EVT2驻留状态启用转矩驱动短时约束，ne_ref列的动力学响应系数严格为零。原静态启发式转矩偏置不是Newton动力平衡；此时以机械惯量和实际/排队转矩的积分响应替代其硬等式，并同时保留原发动机转矩保护、原电机转矩/电池功率/电流电压约束及速率约束。EVT1/未观测阶段不冒充模型已验证。', '',
 '## suburban400：运动学可行域与速度治理', '',
 'all_mode_static_domains.csv列出EVT1、EVT2、EVT1_L在0–120 km/h、原发动机参考域1600–4200 rpm下的区间。当前EVT2下nA=a21 ne+a22 no；旧峰值92.21 km/h所需ne约5060 rpm，不能靠放宽4200 rpm解决。', '',
 '治理上界由整个原始发动机允许参考域的最不利端点推导：v_safe=(6000−a21·ne_min)/(a22·roadPerKmh)=62.607832 km/h。它是可计算的参考域保守治理方案，不是新增电机转速裕度；其必要前提是实际状态能被内环约束在可行域，故没有据此声称硬安全不变性。没有验证动态发动机下界前，没有贸然把治理上界提高到84.86 km/h。', '',
 '本轮原生suburban400全程Motor A/B均无超速；参考降低的每个原生样本见suburban400_governor_native.csv，开始/结束/持续时间/最大偏差见governor_segments.csv。原始请求速度仍用于RMSE、参考里程及里程偏差；安全速度另列。原1 s驾驶员滤波的重建与旧原生请求参考最大差5.28e-12 km/h，见requested_reference_reconstruction.json，未通过改目标美化跟踪。', '',
 '## stress300：真实转矩预测及独立验证', '',
 '状态为实际ne/no、实际Te/TA/TB及其观测变化率，包含原始Je/JA/JB反射惯量；Q由原发动机机械输出因子与传动运动学Jacobian作用于实际转矩组成。未知广义反力由前一观测区间估计；按0.02 s执行延迟分别积分已执行/排队参考与新指令，使用原0.1/0.2 s转矩滞后。未使用ne_ref固定一阶增益，未拟合或训练Transformer。遗漏的轴惯量、齿轮损耗、离合器/制动扰动显式留在未测反力，不能据此声称模型精确或有全局误差界。', '',
 'stress训练区间40–49 s、suburban训练180–230 s；独立验证覆盖用户指定四个stress失败区间及suburban250–355 s。四个预测时域0.02/0.04/0.12/0.22 s，训练样本最大误差作为候选包络，所有独立样本及误差见physical_predictor_summary.csv和*_physical_predictor_validation.csv。包络在该有限验证集合未被突破；仅据此部署实验候选，不宣称任意新状态的硬安全保证。', '',
 '局部真实闭环先运行stress前60 s、suburban前355 s，两电机零超速、发动机>1 Nm零点，专用安全wrapper最大10.0506/5.9960 ms；随后才运行本轮完整300/400 s、固定seed20260906，每组保留150001/200001个原生0.002 s采样点。局部通过未被当成全程通过。', '',
 '## 完整回归新增失败：EVT1边界未通过', '',
 '完整stress300新增Motor A 305点：169.248–169.606 s为180点（0.360 s），170.156–170.404 s为125点（0.250 s）；峰值169.392 s约6313.5347 rpm，发动机约4478.31 rpm、车速约3.097 km/h。该段为EVT1，当前实验预测/投影只在EVT2启用；降低ne_ref并未代表实际转速已降低。旧Transformer该工况A为0点，所以这是必须保留的退化，不能用Motor B改善抵消。', '',
 '随后单独检验EVT1：先前10–20 s不存在合格EVT1训练样本，空集尝试失败并保留，未把NaN/零失败计数当作通过。根据真实驻留区间，改用stress141–160 s与suburban2–10 s，独立验证其它驻留段。evt1_bounds/summary.csv显示各时域包络被突破：stress为33/40/39/49个元素，suburban为72/79/99/97个元素。没有把该包络扩展为控制器，也没有通过增加固定裕度或调权重掩盖这次失败。', '',
 '## 修改前后完整指标', '',
 '|指标|stress前|stress后|suburban前|suburban后|','|---|---:|---:|---:|---:|']
 for key in columns:
  vals=[before['stress300'][key],after['stress300'][key],before['suburban400'][key],after['suburban400'][key]]
  lines.append('|'+key+'|'+'|'.join(f'{v:.9g}' for v in vals)+'|')
 lines+=['', '完整标量、转速最长连续区间/总时长、命令-实际偏差、SOC范围及差值见complete_before_after_metrics.csv。native_statistics包含修改前后每台电机的全部越限点与分段、每个硬约束失败点；无越限保留带表头空表。误差、失败及启动点未删除。等效油耗、SOC变化、里程和原始请求跟踪需共同解释，suburban少耗油并不代表完成了相同驾驶任务。', '',
 '## 剩余电流问题与最小后续接口', '',
 '两组电流仍失败，具体原生采样和模式注释均保留。局部stress613点位于0/1/2阶段（339/220/54点），不只是启动单一时刻。当前数据不足以证明所有这些点物理必然不可消除，因此不作此断言。原四路参考未完整表达这些阶段实际post-PID命令，单独约束参考电功率不能保证执行电流。', '',
 '最小接口扩展方案：在控制模式合并后、原执行器限幅/滞后之前，观测实际Te_com/TA_com/TB_com及其生效时间戳；提供真实stage、range、启动/PID直通选择、必要PI积分与D滤波状态、离合器接合/滑差及制动执行量。对于完整预测，需要可求解的双自由度机械惯量/反力或等价净轴转矩观测，而非把no当作不受候选转矩影响的外部轨迹。', '',
 '执行权限方面，把这些模式产生的三路实际名义转矩送入同一个安全投影，并让其安全结果在物理执行器入口真正生效；保留现有发动机保护，不能让上游PID随后覆盖安全输出。速度治理接口本轮已实现；换挡请求/许可及制动治理目前仍没有，不假定已具备。若以后引入需明确握手和扭矩连续条件。该方案是可审查的下一步接口设计，不代表状态曝光后自动获得安全证明。', '',
 '## 测试、保护资产及交付', '',
 '18项MATLAB测试最终通过，既有12项静态检查通过。新增测试最初因fixture未启用保护标志失败，修正后重测；中间一次shell转义错误导致测试修正未执行，原日志和失败CSV均保留。Code Analyzer、git diff --check和保护哈希另外保存，不将静态/单元通过等同整体验收。', '',
 '原EMT.mdl、原参数与标定、冻结Transformer权重、EMT_ML.slx物理资产、engine_torque_guard.m与update_constraint_guard.m均保持不变。实际控制改变位于源控制器、统一投影及SimulationInput控制输入，所有修改见all_changes.patch；this_stage_changes.patch相对上轮未提交诊断版本在内存重建差异，没有创建源码备份。', '',
 '完整新仿真日志为stress300_full_simulation.log、suburban400_full_simulation.log；full_regression/runs包含本轮run.mat、simulation.mat、配置与全部原生输出；control_local保留局部日志与数据。', '',
 '**最终验收：未通过。** 专用20 ms安全回调、suburban两电机、stress Motor B及发动机>1 Nm保护在本轮数据中通过；stress Motor A、电流和suburban原始请求跟踪仍失败/退化。当前候选不可称为整体修复成功，也不能作为已验收替换。', '']
 (B/'电机转速越限_第二阶段修复与完整回归报告.md').write_text('\n'.join(lines),encoding='utf8')
 print('Report, native failures, timing quantiles, complete metrics and both full logs saved.')


if __name__=='__main__':main()
