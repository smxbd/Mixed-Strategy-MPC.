from pathlib import Path
import json,hashlib
import pandas as pd
R=Path.cwd();B=R/'ml_ems/results/motor_speed_stage3_20261026_001'
read=lambda p:json.loads((B/p).read_text(encoding='utf8'))
a=read('before_after_audit.json');accept=read('acceptance.json');same=read('trajectory_comparison.json')
energy=pd.read_csv(B/'energy_comparison.csv');timing=pd.read_csv(B/'all_callback_timing.csv')
def md(df):
 def value(x):return format(x,'.9g') if isinstance(x,float) else str(x)
 return '| '+' | '.join(df.columns)+' |\n|'+'|'.join(['---']*len(df.columns))+'|\n'+'\n'.join('| '+' | '.join(value(x) for x in row)+' |' for row in df.itertuples(index=False,name=None))
rows=[]
for cycle in ['stress300','suburban400']:
 for phase in ['before','after']:
  s=a[phase+'_'+cycle]
  for m in ['A','B']:
   z=s['motors'][m];rows.append(dict(cycle=cycle,phase=phase,motor=m,samples=z['samples'],peak_abs_rpm=z['max_abs_rpm'],longest_s=z['max_duration_s'],total_s=z['total_duration_s'],segments=z['segments']))
motors=pd.DataFrame(rows);motors.to_csv(B/'motor_speed_comparison.csv',index=False)
rows=[]
for cycle in ['stress300','suburban400']:
 for phase in ['before','after']:
  s=a[phase+'_'+cycle];rows.append(dict(cycle=cycle,phase=phase,engine_gt1Nm_samples=s['engine_violation_samples'],engine_max_positive_excess_Nm=s['engine_max_positive_excess_Nm'],engine_signed_max_excess_Nm=s['engine_max_excess_Nm'],current_samples=s['current_violation_samples'],voltage_samples=s['voltage_violation_samples'],SOC_samples=s['soc_violation_samples'],fallback=s['safety_fallback_samples'],infeasible=s['safety_infeasible_samples'],RMSE_kmh=s['RMSE_kmh'],distance_km=s['distance_km']))
other=pd.DataFrame(rows);other.to_csv(B/'protection_comparison.csv',index=False)
triggers=[]
for cycle in ['stress300','suburban400']:
 d=pd.read_csv(B/(cycle+'_recovery_callbacks.csv'));z=d[d.recovery_active>0]
 triggers.append(dict(cycle=cycle,count=len(z),first_s=float(z.time_s.min()) if len(z) else None,last_s=float(z.time_s.max()) if len(z) else None,max_applied_prediction_residual=float(z.applied_prediction_residual.max()) if len(z) else None))
(B/'recovery_summary.json').write_text(json.dumps(triggers,indent=2),encoding='utf8')
protected=['EMT.mdl','parameter.m','parameter.mat','ml_ems/models/EMT_ML.slx','ml_ems/controllers/common/engine_torque_guard.m','ml_ems/controllers/common/update_constraint_guard.m']
hashes={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in protected};(B/'protected_source_hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf8')
bound=pd.read_csv(B/'long_input_sequence_validation.csv')
fresh=pd.read_csv(B/'round4_long_input_sequence_validation.csv')
check=fresh[fresh.split=='test'].merge(bound[bound.split=='train'][['horizon_s','max_abs_error']],on='horizon_s',suffixes=('_fresh','_baseline_bound'))
check['absolute_bound_pass']=check.max_abs_error_fresh<=check.max_abs_error_baseline_bound
check['upper_A_underestimate_bound_pass']=check.max_underestimate<=check.max_abs_error_baseline_bound
check.to_csv(B/'fresh_prediction_bound_check.csv',index=False)
provenance=read('calibration_provenance.json');provenance['long_input_sequence_validation']=bound.to_dict(orient='records');provenance['accepted_max_horizon_s']=.4;provenance['rejected_horizon_s']=.5
provenance['validation_note']='Future command sequences are observed only for offline model validation. Online candidates assume the issued action held after the verified transport delay. Bounds are empirical on declared slices, not a global invariant.'
(B/'calibration_provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf8')
passed=all(x['this_round_pass'] for x in accept.values())
text='''# 电机转速越限：第三阶段最小修复与完整回归

## 结论及验收范围

'''+('本轮电机转速、发动机转矩及专用安全回调预算的专项回归通过。' if passed else '本轮专项回归未通过，不得宣布整体修复成功。')+'''
本轮仅运行 stress300 300 s 和 suburban400 400 s，seed=20260906；全部原生 0.002 s 样本参与统计。未运行 city200。Existing EMS 使用已注明路径的历史基准，仅用于能耗对照；after 全部来自本轮新仿真。

这不是对所有工况的数学安全证明。预测误差边界来自明确独立片段的经验验证；模式切换、Te_ref≤10 的闲置 PID 分支没有被伪装成已辨识执行器。原项目综合验收中的电流、速度跟踪指标继续如实记录，本轮没有更改其阈值或删除硬安全保护。本轮按用户最新范围，不将它们作为优化目标。

## 根因

最新基线 Motor A 的 305 点分为 169.248–169.606 s（180 点，样本支持 0.360 s）和 170.156–170.404 s（125 点，0.250 s）。最大绝对转速 6313.534718 rpm，典型峰值时发动机实际约 4478 rpm、车速仅约 3.1 km/h，处于 EVT1。已发 ne_ref 不能约束实际发动机转速；原有运动学参考区间仅能限制参考数值。先前物理转矩预测只在 EVT2 生效，EVT1 没有针对实际转速的可达性管理。

EVT1 中发动机轴和输出轴惯量存在耦合。将车辆侧转速当作独立外推量，会漏掉两台电机转矩对车辆侧和发动机侧加速度的共同影响；后向差分又对应前半个控制周期的速度。原模型转矩执行器存在 20 ms 待执行指令、零阶保持和发动机/电机转矩滞后（0.1/0.2/0.2 s），单靠下一周期越限检查无法制止正在加速的转子。

另一个真实接口边界是 EVT1_H Stage/engine torque 的原有 Switch：Te_ref>10 时选择直接参考，否则选择怠速 PID。历史零参考时通过精确 ZOH 反演得到的实际输入仍可为 91–233 N·m。因此不能将零发动机转矩参考视作零执行输入，也不能将 ne_ref 视作直接转速执行器。原图、PID、发动机保护均保持不变。

## 修改机制及最小范围

1. 新增 evt1_motorA_constraints.m，仅在 stress300、EVT1、连续可观测运动状态及待执行 Te_ref>10 的情况下建立物理预测。发动机速度参考在约束矩阵中的系数严格为零。采用原参数的 2×2 耦合惯量矩阵，联立发动机与输出轴动量方程，将实际转矩、待执行转矩和新发转矩分别计入。
2. update_evt1_motion.m 只补充输出轴加速度；原发动机观察器 update_constraint_guard.m 和 engine_torque_guard.m 字节不变。初始瞬时速度导数使用后向差分加半个观测周期的加速度校正。
3. 在现有 QP/约束残差中并入同一组 Motor A 预测不等式，复用发动机转矩上界、电池功率、电压、SOC、指令变化率等原保护。新增约束数量固定为 17，普通 QP 与仅在失败时尝试的紧急 QP 各为四个功率符号区域、每区域最多 64 次迭代；无额外独立限幅器或实时文件 I/O。
4. 首轮仅使用 20/40/60 ms。新真实仿真仍有 170 个越限点，峰值 6303.122332 rpm，169.248–169.586 s，发动机及 Motor B 通过。原始失败数据和日志保存在 round1，未删除。原因是 60 ms 内可改变的转矩不足以消除上升动量，进入不可行状态后已有保护无法追回。
5. 第二轮在离线验证后增加 100/160/220/300/400 ms 的有界预测，使现有投影提前开始协调三路转矩。只有待执行参考保持的预测逼近硬边界时才激活。每个时域使用训练片段得到的对应误差边界，未增加任意固定转速裕量，未修改权重。
6. 第二轮虽清除了旧 169–170 s 越限，仍新出现 3.522–3.712 s 的 96 点越限，峰值 6102.801835 rpm。实际原因是活动判定只看待执行指令保持的轨迹，没有同时检查本次 raw 候选。上一条安全、下一条危险的情况下，危险指令可在当次绕过动态约束，随后再激活已来不及。最终修复在现有投影入口，用同一个模型同时检查 pending 和 raw；仅刷新缓存中的电机预测，保持缓存中的发动机和电池保护原值。新增单元测试覆盖此问题，原始 round2 数据保留。
7. 第三轮 Motor A 仍有 455 点，峰值 6479.831426 rpm。针对 3.6 s 起的实际失败轨迹离线检查发现，QP 无解时原有回退网格仍强制静态转矩平衡，不能独立选择两台电机的保护转矩；指令变化率约束冲突使正常 QP 不可行。实际 replay 在 3.62–3.70 s 可找到满足全部物理/预测约束的独立转矩点，但所需指令变化超过正常 slew 限制。最终在现有回退路径增加同一个 QP 的紧急求解：静态执行边界、发动机上界、原电池/电压/SOC 功率约束和预测速度约束全部保留，只沿用原网格回退已有的越过指令 slew 机制。并非解除执行器滞后；真实滞后仍在预测式内。该指令仍以 fallback/infeasible 和 slew 残差记录，不伪称所有原约束均可行。若物理约束无解，则仍退回原路径并记录失败。新单元测试确认正常 QP 失败、紧急 QP 物理残差通过且 slew 残差保留。
8. 风险状态下保持 Te_ref 严格大于原有 10 N·m 分支阈值，数值分隔量为 2×原 constraint_tolerance，以免求解容差把指令放回闲置 PID 分支。若原发动机上界不允许，则仍服从发动机上界并保留不可行记录，绝不提升发动机允许转矩。未新增换挡、制动或速度治理接口；suburban400 沿用上一阶段已通过的治理和 EVT2 控制。

机械模型为 M=[I_e,C;C,I_o]，其中 I_e=Je+JA*a11²+JB*b11²，C=JA*a11*a12+JB*b11*b12，I_o=mass*rz²/ratio²+JA*a12²+JB*b12²，ratio=(1+kh)/kh*ic。速度导数由原 Y_engine 系数及两台电机原运动学系数换算。

转矩增量积分使用 F(h,τ)=h−τ(1−exp(−h/τ))、Fa=F(max(0,h−20 ms),τ)，增量为 (待执行−实际)*F+(新发−待执行)*Fa。该式使用原模型真实转矩滞后，不是虚构的转速参考一阶响应。

## 离线预测验证

训练片段为旧 stress300 的 EVT1 141–160 s；独立验证为 161–177.5、202.6–222.5 和 2–9 s。只采用同一模式及直接转矩分支内的窗口。20/40/60 ms 的独立误差最大分别为 8.320/16.001/26.654 rpm，小于训练边界 10.767/21.519/26.999 rpm。

较长预测的验证必须使用历史实际未来指令序列，因为历史控制器会在预测时域内改变指令；把单个指令保持预测直接对照已换指令的历史轨迹，会把控制动作差异误算成模型误差。离线用记录的分段 ZOH 指令驱动同一个解析动力学模型，在线仍只使用可知的实际/待执行状态及候选指令。较长时域的逐点输入序列验证及边界如下：

'''+md(bound)+'''

400 ms 独立最大误差 208.540 rpm 小于训练边界 216.041 rpm；500 ms 的独立误差 280.852 rpm 超过训练边界 269.724 rpm，明确拒绝。round1 新控制轨迹的独立验证也保留在 round1_long_input_sequence_validation.csv；这部分没有用于重设边界。全部逐点误差保存在 *_long_*_points.csv，旧短时模型比较保存在 prediction_variants.csv。

最终 round4 新轨迹上的独立输入序列复核如下。部分中间时域的绝对误差越过旧经验边界，来自负误差（过度预测转速），而本轮正向 Motor A 风险的上侧欠预测量仍在旧边界内；这也明确说明经验双侧边界不能视作全局证书，不能把新轨迹的复核全部宣称为通过。500 ms 继续不使用。

'''+md(check)+'''

经验边界不覆盖任意未来载荷和未经观测的 PID/模式切换，故代码明确保留 command_response_certified=false。完整仿真通过可以证明本轮两条测试轨迹通过，不能据此声称全状态空间的不变集保证。

## 原生转速逐点及分段结果

'''+md(motors)+'''

native_statistics 中 before、failed_round1、failed_round2、failed_round3b、after 各自保留 Motor A/B 的全部越限点 CSV 和连续段 CSV。空 CSV 也保留列头。段时长为原生样本支持时间，含最后一个越限样本到下一个样本的 2 ms；未删异常点或使用降采样。

## 发动机保护及其他真实指标

'''+md(other)+'''

正向发动机越界量同时报告 max(0,Te−原表上限) 和未截断的最大有符号差。既定验收为 Te−上限>1 N·m 的点数，不修改为其他口径。当前、SOC、电压和 RMSE 继续使用原项目统计。电流失败项没有删除；不为优化该项改变燃油或控制权重。

## 燃油与 SOC

'''+md(energy)+'''

累计油耗与 SOC 必须合看，SOC 减少表示使用电池能量。Existing 与当前控制器的实际里程和跟踪并不完全相同，以上累计燃油百分比不能单独解释为等里程的公平节油率。完整 CSV 同时提供百公里油耗、等效油耗、参考/实际里程和误差；本轮未更改这些公式。

## 实时性

'''+md(timing)+'''

专用 safety 行包括四次优化决策之间所有真实安全 wrapper，从入口计到日志写入及运行状态更新完成，使用最大值、P95、P99 和超时数判定 20 ms。decision 行为原有 100 ms 周期优化决策 wrapper，单列其总耗时；all_wrappers 行也完整披露，不能将专用安全预算通过表述成全部 EMS 计算均小于 20 ms。初始化预热不计作在线回调，在线没有删除慢样本。

## 回放、测试及文件差异

25 项 MATLAB 单元测试通过，包含耦合矩阵/转矩作用方向、20 ms 待执行隔离、ne_ref 零控制系数、远离风险不动作、闲置 PID 分支不伪造权限、suburban 隔离、安全 pending/危险候选不会漏检，以及发动机和电池保护上限不变，以及紧急回退仍严格验证全部物理约束并记录 slew 超限。原有静态测试结果保留在 static_checks.log，新增和改动 MATLAB 源码 checkcode 输出及全回调离线事件重建一致性见 postflight.log。离线分析不在实时回调内运行。

'''+md(pd.DataFrame(triggers))+'''

所有重建事件与实时 command/state residual 逐项核对；详见 *_offline_events.mat 及 postflight.log。*_recovery_callbacks.csv 保留每个真实回调的活动状态、预测及实际已发指令残差。

轨迹比较：

```json
'''+json.dumps(same,ensure_ascii=False,indent=2)+'''
```

核心新增/修改文件：controllers/common/evt1_motorA_constraints.m、prepare_evt1_candidate_guard.m、update_evt1_motion.m、motor_prediction_constraints.m、constraint_residual.m、project_to_feasible_set.m、project_qp.m、warmup_safety_paths.m，controllers/ems_runtime.m；另有单元测试及离线分析脚本。未修改 .slx 物理结构、原表或 Transformer 权重。

this_round_changes.patch 相对上一阶段已保存的完整 Git diff 在内存中重建基线，展示本轮增量；all_changes.patch 是当前 Git 工作区相对 HEAD 的全部改动，包含前序未提交修改及新增文本源。未创建项目备份或重新训练。round4/protected_hashes.mat 与当前 protected_source_hashes.json、round4/status.json 中 protected_unchanged 核对原始物理模型、标定数据和发动机保护未变；冻结权重同时受原运行策略哈希校验。

两组原始完整仿真目录及日志见 round4/status.json、stress300_full_simulation.log、suburban400_full_simulation.log。原模型既有 Simulink 警告完整保留。失败三轮日志 round1/validation.log、round2/validation.log、round3b/validation.log 均保留。round3 的前置测试曾因测试夹具缺少 synchronous_speed 字段失败，修正夹具后重新全测，并在最终 round4 全部通过，未跳过失败测试。

## 验收判定

```json
'''+json.dumps(accept,ensure_ascii=False,indent=2)+'''
```

'''+('按本轮用户明确范围，两个工况的电机速度、发动机正转矩和专用安全预算均通过。本轮专项修复完成；仍不宣称原项目全部诊断指标通过，也不宣称预测具有全工况硬安全证书。' if passed else '至少一项本轮硬验收失败，整体修复未完成；以真实保留的数据为准。')+'\n'
(B/'电机转速越限_第三阶段修复与回归报告.md').write_text(text,encoding='utf8')
print('REPORT',B/'电机转速越限_第三阶段修复与回归报告.md')
