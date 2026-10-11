# 阶段 A：模型拓扑与接口静态审计

审计对象为工作目录中的 `EMT.mdl`，SHA-256 为 `4bd17a7cb3f68d9ba965e3babbf599d0d306e61c73aa6e0ddcbc26629906baa6`。本报告只读解析 OPC 文本包、XML、SID 和连线；未调用 MATLAB、未编译或仿真，不能替代实际加载或约束验证。文中 `L` 均指该原始文件的一基行号；块名中的尾随空格属于实际名称。

## 1. 实际模型版本与结构

主文件头、metadata 都明确为 **R2024b / 24.2.0.2712019**，不是请求说明中的 R2024a（L1–6、L58–60、L74–78）。文件扩展名是 `.mdl`，内容为 MathWorks OPC Text Package。静态解析得到 **274 个 System、2358 个 Block、10 个顶层子系统**。

| 顶层对象 | SID | 行号 | 应保留内容 |
|---|---:|---:|---|
| Battery | 959 | 44803 | 电池、电气负载、SOC 估计与测量 |
| Control Unit | 15 | 44814 | 驾驶员、分配器周边、模式与底层控制 |
| Front Gear | 8620 | 44824 | 前传动、C0 |
| Power Coupler （尾随空格） | 1276 | 44843 | k1–k4 行星排、C1/Z1/Z2 |
| Rear Gear | 8834 | 44853 | 后传动 |
| Simulation Results | 22733 | 44872 | 原有观察信号 |
| Vehicle dynamics | 8659 | 44881 | 左右车辆动力学、坡度与地面阻力 |
| engine | 1130 | 44890 | 发动机物理模型与转矩限制 |
| motorA | 1297 | 44899 | 电机 A 物理模型与限制 |
| motorB | 1461 | 44908 | 电机 B 物理模型与限制 |

真实替换定位为：

```text
EMT/Control Unit                         SID 15
  /Control                             SID 16
    /Power Distribution                SID 11143
      /Optimal Power Distribution      SID 11342
        /Optimization␠                 SID 11353
```

`␠` 表示一个尾随空格。建议建模脚本通过 SID 定位后确认全路径，避免误用不含空格的路径。

## 2. 19 项输入的真实封装

`Optimization ` **不是 19 个输入端口、4 个输出端口**，而是 MATLAB Function 的 **1 个 19 维向量输入 `u`、1 个 4 维向量输出 `y`**（SID 11353，L13156；内部 Inport SID `11353::1`、S-Function SID `11353::27`）。父 `Optimal Power Distribution` 有 10 个输入端口和 4 个输出端口。

父层 10 路输入与内部常数 `ZD_k` 先进入 `Subsystem`（SID 11358，L13178）形成 11 路，再由 `Mux`（SID 11384，L13543）拼接，通过 `Fcn u(1)` 至 `Fcn u(19)` 后由 `Mux1`（SID 11385，L13551）重新组成 19 维向量。新接口应明确每一维，不能按块输入端口数猜测。

以下为向量顺序和上游连接证据；变量算法用途另见控制算法审计。

| u 索引 | 名称 | 上游真实来源 | 关键证据 |
|---:|---|---|---|
| 1 | Pe_com | Pedal Interpretation 输出 2 → 父 Inport 1 | 11391 L11501 → 11343 L13101 |
| 2 | pedal | 全局 Pedal → 父 Inport 2 | From 13893 L11429 → 11344 L13105 |
| 3 | ZD | 内部 Constant `ZD_k`，不连接驾驶员负载 | 21448 L13193；Value 未显式序列化，应运行时核对默认值 |
| 4 | stage | Feasible Control Range 输出 1 → stage_k | 11165 L11377 → 11345 L13110 |
| 5 | ne_act | ne_k 向量第 1 项，来自延迟后的 ne_act | 15615 L17566 → Mux 15617 L17576 |
| 6 | ne_max | ne Range 输出 1，经发动机速度范围限幅 | 15620 L17598 → 15680 L17584 |
| 7 | ne_min | ne Range 输出 2，经发动机速度范围限幅 | 15620 L17598 → 15681 L17591 |
| 8 | no_act | v_act 按传动参数转换，经 no_k | 11205 L12094：`u*(1+kh)/kh*ic/0.377/rz` |
| 9 | Te_max | 当前 ne 查 `ne_map / Te_max_map` | 11240 L12645 |
| 10 | Te_min | 常数 0 | 11238 L12634 |
| 11 | TA_max | 推算 nA 查 `nA_map / TA_max_map` | 11219 L12424 |
| 12 | TA_min | 推算 nA 查 `nA_map / TA_min_map` | 11220 L12437 |
| 13 | TB_max | 推算 nB 查 `nB_map / TB_max_map` | 11227 L12529 |
| 14 | TB_min | 推算 nB 查 `nB_map / TB_min_map` | 11228 L12542 |
| 15 | PN_com | SOC 电池需求查表 − ElectricPower − PN0 | 11148 L11650、11151 L11683、11152 L11691 |
| 16 | PN_max | 电压查 `Voltage_epr / Pb_max` | 11149 L11661 |
| 17 | PN_min | 电压查 `Voltage_epr / Pb_min` | 11150 L11672 |
| 18 | PZ_com | 常数 0，PN_k 第 4 项 | 21447 L11722 |
| 19 | sd_ne | `ne_ref - ne_act` 的离散 PID 输出 | 22284 L11508；22280 L33444；22282 L33490 |

`State Predition` 是原模型的实际拼写（SID 11211）。其 nA、nB 来自传动关系推算，不是直接连接的传感器 nA/nB。`Feasible Control Range` 对 ne_act、v_act 分别经过 Memory（SID 18937、18938）。安全层设计必须区分当前实测转速、经过延迟的状态和候选动作所对应的预测转速。

电压通道 `Memory7`（SID 18939，L11709）的 `InitialCondition` 写为 **SOC0**，与电压量纲不一致，是待隔离验证的问题。不能在基线复现时直接修正后声称与原模型等价。

## 3. 4 项输出与底层控制接口

`y=[ne_ref;Te_ref;TA_ref;TB_ref]` → `Rate Transition2`（SID 22199，L13173）→ `Demux`（11352）→ 父层四个 Outport（11387–11390）→ 全局 Goto（11332、11334–11336）。

| 输出 | 实际下游 | 不应绕过的控制 |
|---|---|---|
| ne_ref | `Power Distribution/Subsystem/From9` SID 22277，L33481；Engine Viewer | 与 ne_act 形成 sd_ne 反馈；不是直接接发动机速度源 |
| Te_ref | EVT1_H/engine torque SID 21024；EVT2/engine torque 21088；两换段方向 21287、21319 | EVT1_H 内部转矩控制、模式选择、发动机开关与执行器转矩限制 |
| TA_ref | EVT1_H 21042；EVT2 21091；换段 21290、21322 | 准备/换段逻辑与电机执行器限制 |
| TB_ref | EVT1_H 21045；EVT2 21094；换段 21293、21325 | 准备/换段逻辑与电机执行器限制 |

控制状态分支为 `Prepare Stage`（21113）、`EVT1_H Stage`（20986）、`Shift Stage`（21266）、`EVT2 Stage`（21051）。`Stage Judge`（21360）驱动 0 基 Multiport Switch（21112，L18187），四个数据端分别对应 0、1、2、3。注意这仅说明分支选择编码，不等于所有内部 `stage` 枚举值。

分支输出继续由 Control Unit 的 Demux（44，L17059）拆成 `Press、engine_switch、Te_com、TA_com、TB_com、TZ_com、Fb_com`。执行器使用这些 `*_com`，不是高层 `*_ref`。`Oil Control`（22249）把 Press 的四项分别经 `[TS_C0 1]`、`[TS_Z1 1]`、`[TS_Z2 1]`、`[TS_C1 1]` 滤波后送往离合器/制动器。

## 4. 真实循环通道与未连接分支

| 通道 | 当前实际生效路径 | 结论/后续适配 |
|---|---|---|
| 目标车速 | Driver/Pedal␠/Subsystem：Clock → `Time/v_cyc` Lookup（22002，L31074）→ `1/(s+1)`（22008，L31129）→ v_com | 驾驶员使用滤波后的 v_com；v_com-v_act 为 dv_act。原始循环目标与滤波目标都应记录 |
| 踏板 | Auto（21839）+ 手动调整分支 → ±1 Saturation → `1/(0.02s+1)` → Pedal | 当前 Auto 分支有实际连接；保留该驾驶员，改变循环数据 |
| 用电负载 | Clock → `Time_ele/ele_map`（22900，L25976）→ [0,300] 限幅 → `1/(0.02s+1)` → ElectricPower | 同时进入高层需求和 Battery/Battery/Electronic Equipment，具有物理负载作用 |
| 地面阻力 | Constant Forward1=0.045（22932，L28842）→ fg_act | Road、Road1、随机扰动/滤波等支路没有接最终 Goto；不能将其输出当作实车阻力 |
| 坡度 | Constant Forward1=0（22940，L27664）→ angle | 动态角度支路/滤波不接最终 Goto；Vehicle dynamics 的坡度项为 `0.5*mass*9.8*sin(u)`，角度单位应为 rad |
| 转向 | Wheel Angle/Subsystem2（22137）→ Wheel Goto（22108） | Wheel 的 From 仅存在于两个结果查看器，未发现接车辆/执行器；新增 steering_angle 数据本身不会改变物理运动 |

车体包含 Steering Resistance 子系统，但其依据是 v_Left/v_Right 速度差（例 SID 10449），并非 Wheel 信号。未来应把 steering_angle 标为“仅记录”直至明确物理转向接口并进行单因素验证；不能凭有此字段就宣称完成转向鲁棒性实验。

Driver/Pedal␠ 内的 Signal Builder（22936）、另一组时间踏板 Lookup（22933）和滤波输出未接最终 Pedal 路径。`v_act > 120` 经比较器（22262，L30516）连接 Stop Simulation（22265，L30641），属于需记录的统一提前停止条件。

## 5. 保护逻辑边界

已明确定位的约束包括高层发动机速度可行区、发动机/电机转矩表、SOC 电池功率请求、电压相关 Pb_max/Pb_min，以及物理执行器内动态转矩限幅。motorA 的 `Max & Min Torque Control`（1396，L16037）和 motorB 的 `Max & Min Speed Control`（6255，L41235）内部均是按转速查最大/最小转矩再 Saturation Dynamic；不能只依据后者名称推断存在独立的硬转速保护。

电池 `SOC Estimation`（16636）实现电流积分：`SOC0 - integral(I/Cb)/36`（16642，L19053），SOC 使用百分数标度，正电流降低 SOC。该子系统没有显式 SOC 输出限幅；上层 Lookup 输入限幅不等于电池物理状态永不越界。本次静态证据不足以证明已有电流/电压/SOC全局硬保护完整。未来安全层应保留已有逻辑并新增可度量的约束检查，而不预先声称“原模型已保证所有硬约束”。

## 6. 采样、依赖与运行风险

| 对象 | 静态参数 | 证据 |
|---|---|---|
| 模型 | 固定步长 0.002，ode5，StopTime=1500 | L2705、L2708、L2723 |
| Control Unit | SystemSampleTime=0.02 | SID 15 |
| Feasible Control Range | SystemSampleTime=0.02 | SID 11165 |
| Optimal Power Distribution | SystemSampleTime=10，但未显式 TreatAsAtomicUnit | SID 11342 |
| Optimization␠ | TreatAsAtomicUnit=on，SystemSampleTime=0.02 | SID 11353 |
| sd_ne PID | Ts=0.5，Kp=0.5，Ki=0.1，Kd=0，输出限值 [200,-200] | SID 22280 InstanceData |

有效执行采样率必须查询 compiled sample time。父层“10”与原子层“0.02”不能合并猜测；新 0.1 s CEM 控制与 0.5 s sd_ne 回路亦应设计明确速率转换。

模型加载前/初始化回调均调用 `parameter;`（L2648–2649），停止回调为 `save('result.mat');`（L2650）。加载本身就可能触发原脚本副作用，必须在隔离的工作副本验证；不能只在仿真停止前处理覆盖风险。

静态 Reference 计数：fl_lib 82（Simscape 基础物理）、nesl_utility 55（转换/求解配置）、sdl_lib 10（传动/离合器）、simulink 49、simulink_need_slupdate 6（旧 PID）、powerlib_extras 1（sd_ne 离散 PID，需核查对应库/产品可用性）。这只是依赖线索，不等于许可证或实际链接已通过。

模型仅显式使用一个 S-Function：`sf_sfun`（MATLAB Function 的 Stateflow 包装）。未发现显式 `EMT_sfun` 引用，也没有 ModelReference Block。`EMT_sfun.mexw32` 是历史 32 位编译物，后续从内嵌函数源码构建，不应作为 R2024b 依赖。当前两个 `.slxc` 的 metadata 均为 R2019b；slprj 下存在 Stateflow/JIT/cache 历史文件。应在新工作区设置独立缓存路径并保留原文件。

## 7. 版本比较的有限结论

| 文件 | 静态版本信息 |
|---|---|
| EMT.mdl.r2011b | MDL Version 7.8 |
| EMT.mdl.r2015b | MDL Version 8.6 |
| EMT.mdl.r2016b | MDL Version 8.8，LastSavedArchitecture win64 |
| EMT.mdl.r2024a | OPC R2024a / 24.1 |
| EMT.mdl | OPC R2024b / 24.2 |
| EMTtest02.slx | ZIP metadata R2016b / MATLAB 9.1.0.441655 |

与 r2024a 比较，两者都是 2358 块；同 SID 块的直接 P 参数中变化仅有 148 个 LibraryVersion 和 1 个 ScopeSpecificationString；MATLAB Function 的 3 个内部包装 SID 发生重编号，chart_7 XML规范化序列化内容相同。配置新增/变化项包括 SimscapeCompileArtifactsDiskCache、UsePrecompiledLibraries、AnnotationsInComments。此比较没有证明运行数值一致，也不能证明不同年代备份彼此等价。

## 8. 对文件级改造计划的约束

1. `ml_ems/models/EMT_ML.slx`：从经隔离验证的主模型复制；仅替换 SID 11353 对应算法及接口适配，继续输出原四个参考值，并保留全部模式、准备、换段、Oil Control、底层模型。
2. `ml_ems/models/build_emt_ml.m`：以 SID/实际路径检查前置结构；在副本清除危险回调；安装 19 维兼容适配层和新总线；配置独立缓存和结果目录。结构不匹配时停止生成，不能静默接错信号。
3. `ml_ems/config/`：按量纲拆分参数；保留所有旧限制与转矩表；加入新控制周期、预测周期、原模型周期、sd_ne 周期和限制状态说明。
4. `ml_ems/cycles/`：保留 Time/v_cyc 驾驶员行为；把 road/grade/aux 确认接入当前生效的 Goto 前端；同时记录循环原始值与滤波后的实用输入；转向暂显式标识“无物理接口”。
5. `ml_ems/controllers/`：Existing 适配器保留原 19→4 契约；所有新方法共享当前限制，结果经安全层再送原 Rate Transition/输出端。
6. `ml_ems/tests/`：先核查 get_param 的未序列化默认值与 compiled rates；其次验证两条初始化路径、原型完整保护、各通道单因素激励、旧新基线数值容差。只有这些验证通过才能推进机器学习闭环。

机器可读证据见 `../analysis/evidence/topology_static.json`，包含精简块层级、关键连线、Tag 消费者、依赖和版本哈希。没有生成或填报任何性能结果。
