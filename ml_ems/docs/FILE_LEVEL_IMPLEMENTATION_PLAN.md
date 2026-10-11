# 文件级实施计划：阶段 B–F

状态：设计计划，非已实现功能。阶段 A 的实际交付和运行证据见 `STAGE_A_REPORT.md`。
根路径：项目下 `ml_ems/`；原项目根目录中的模型、脚本、MAT、图片及缓存均保留。

## 1. 实施原则和决策

1. 首先保留一个可重现的原算法基线，正式名称 **Existing heuristic-grid EMS**。已发现的候选索引及降级逻辑问题单独登记；不可在“等价重构”时静默修复。需要修正时，增加 `existing_grid_corrected` 实验标签，并报告原/修正两者。
2. `models/EMT_ML.slx` 必须经安装的 R2024b 加载有效源模型，再用 `save_system` 保存；不通过改扩展名或拼接 ZIP 冒充新模型。阶段 A 不产生这个文件。
3. 保留发动机、电机、电池、行星传动、EVT 模式/换段控制、离合器、制动器、跟踪器与保护。修改范围限于高层 EMS、输入工况和日志适配；保留 `sd_ne` 的原反馈路径。
4. 初次等价验证保持原 EMS 原子块存储周期 0.02 s、相关 PID 0.5 s、模型固定步长 0.002 s。以编译结果确定有效周期。新预测/MPC 周期拟为 0.1 s；若公平实验统一到 0.1 s，原算法需单列 `Existing-grid@0.1s`，不能用它替代原周期基线并声称等价。
5. 19 个原信号通过显式映射接入统一命名总线，所有方法看到相同可观测状态；预测器不得读取循环文件未来索引。只有 DP 离线求解器可读取完整循环，回放接口明确标识离线参考。
6. 原地面阻力和坡度是常数；转向没有车辆物理作用。先复现旧接线，再对所有方法一起启用新的多通道接口。转向若需要物理影响，必须另行验证相应动力学；不得仅靠新增日志宣称已实现。
7. 原 EMS 的降级会放松物理限制，因此“回退 Existing EMS”不等于安全。回退动作也要检查硬约束；若硬约束集合为空，按现有保护请求降载/制动/最小风险动作并记录不可行事件，不承诺不存在物理违规。
8. 主成本用发动机 BSFC 图换算质量流率；不得将现有 `fuel_map`（g/kWh）误当 g/s。电池放电为正、充电为负；等效燃油用净电池能量减少量校正。

## 2. 阶段 B：参数、工况、结果框架及等价基线

| 新文件 | 职责/接口 | 依赖或验收 |
|---|---|---|
| `startup_ml_ems.m` | 返回项目绝对路径及工具箱检查；只配置必要搜索路径 | 无 `clear all`、无自动绘图、可重复执行 |
| `config/init_vehicle_params.m` | `p=init_vehicle_params(overrides)`；发动机/电机/电池/整车原数值逐项迁移 | 对照 `parameter.m` 和原 `parameter.mat`；报告冲突 |
| `config/init_transmission_params.m` | 传动比、效率、惯量和分阶段关系参数 | 消除新增代码中的硬编码，但保持原值 |
| `config/init_controller_params.m` | 周期、全部代价权重、CEM、保护、归一化和变化率设置 | 所有 EMS 读取同一限制；版本化 |
| `config/experiment_config.m` | 方法名/ID、种子、初始状态、停止条件、密度、LHV、等效效率、容差 | 密度初始沿用 0.84 kg/L；LHV/等效效率需有来源并做敏感性分析 |
| `config/legacy_workspace_adapter.m` | 把结构化参数映射到原模型用到的变量名 | 先用 `SimulationInput.setVariable` 覆盖；若变量移入模型工作区，显式指定 Workspace |
| `cycles/build_city200.m` | 原城市循环逐点保留，输出统一结构 | 单位声明；duration=200；核对原时间节点 |
| `cycles/build_suburban400.m` | 按当前注释恢复郊外400 s时间节点 | 不使用未被明确选中的1500/1600 s旧循环 |
| `cycles/build_stress300.m` | 可复现的300 s速度/坡度/阻力/电负载挑战 | 不预称一定频繁切段；以日志实际切段次数验证 |
| `cycles/validate_cycle.m` | 时间严格递增、长度一致、有限值、单位和边界校验 | 拒绝长度不符和超边界；禁止隐式外推 |
| `cycles/load_cycle.m` | 保存/加载带版本、seed、channel_units 的循环 | 同时保留原采样节点和0.1 s公共采样版本 |
| `cycles/perturb_cycle.m` | 按轨迹施加可追溯扰动 | 初值、参数和工况扰动一致，训练/测试ID分离 |
| `models/build_emt_ml.m` | 复制源模型、清除新副本破坏性回调、接 EMS/工况/日志并保存 SLX | 通过 SID/端口确认；处理 `Optimization ` 尾随空格 |
| `models/create_ems_bus.m` | 创建 `EMSInputBus`、输出/诊断总线和19→命名字段映射 | 原19维顺序不可改变；新增观测有可用性标志 |
| `models/configure_logging.m` | 信号名、单位、采样率、日志 Dataset统一登记 | 使用每个信号自己的time，不借用截断tout |
| `models/configure_run.m` | 每次运行隔离缓存、停止时刻、初值、日志与模型变量 | 不继承1500 s及末1000点截断设置 |
| `evaluation/run_experiment.m` | `run=run_experiment(cfg,cycle,method,seed)`；构造 SimulationInput 和处理 SimulationOutput | 成功/失败均保存配置、诊断、MATLAB版本、耗时 |
| `evaluation/compute_metrics.m` | 基于真实时间戳积分/对齐；统一燃油、SOC、跟踪、计算和违规指标 | 缺少信号返回 NaN+reason，不以0替代未测 |
| `evaluation/create_run_directory.m` | `results/<experiment>/<cycle>/<method>/<seed>/<timestamp_UUID>/` | 检查路径已存在即拒绝覆盖；记录输入hash |
| `tests/test_parameter_equivalence.m` | 数值/维数/单位核对；不变性测试 | 对有效参数与原脚本结果逐项比较 |
| `tests/test_baseline_equivalence.m` | 原模型与包装新模型同初值、同周期、同工况配对比较 | 速度/SOC/Pe/PA/PB的abs+rel容差、最大误差和RMSE；先固定容差再运行 |
| `tests/test_cycles_and_metrics.m` | 用已知积分轨迹测试燃油、距离、SOC与时间对齐 | 单位及功率符号需可测验证 |

新模型去除的回调：`PreLoadFcn=parameter;`、`InitFcn=parameter;`、`StopFcn=save('result.mat');`。只在副本内替换为明确的运行初始化，原文件保留。图标路径改为工程绝对路径或模型包资源，但不改变物理模型。

建议初始等价容差（尚未校准，不是通过标准的事后调整）：速度 `atol=1e-4 km/h, rtol=1e-6`，SOC `atol=1e-7（0–1）, rtol=1e-6`，主要功率 `atol=1e-3 kW, rtol=1e-5`；离散模式序列一致。若数值求解迁移超容差，保存差异和原因，经证据决定是否调整。正式主实验应另设速度 RMSE 可接受恶化阈值和终端 SOC 配对/校正标准。

## 3. 阶段 C：传统控制器与安全边界

| 新文件 | 职责/接口 | 验收重点 |
|---|---|---|
| `controllers/controller_registry.m` | ID 1–8 和稳定方法名，登记每个控制器需要的模型文件 | 缺权重/DP计划时明确失败，不偷偷改用 Last-value |
| `controllers/ems_step.m` | `[u,diag,state]=ems_step(obs,state,cfg)` | reset、随机流、因果历史、相同输出结构 |
| `controllers/existing_grid_ems/existing_grid_ems.m` | 冻结原 source 与19维向量包装 | 对照逐点输出；保留原算法已知行为 |
| `controllers/common/transmission_relations.m` | stage→转速和力矩平衡，可带惯量/离合器状态扩展 | 与原模型关系核对，模式切换期间不滥用稳态公式 |
| `controllers/common/fuel_rate.m` | BSFC插值×有效机械功率/3600，输出 g/s | 轴顺序、外特性、零/负功率、图外点；怠速燃油未标定须标记 |
| `controllers/common/battery_limits.m` | SOC、电压、电流、电功率边界及符号 | 两端口/发电负载等损耗避免重复计入 |
| `controllers/common/reduced_vehicle_step.m` | 供ECMS/DP/CEM使用的降阶预测模型 | 在留出高保真轨迹验证SOC/功率/速度误差 |
| `controllers/common/project_to_feasible_set.m` | 联合满足转速、转矩、功率、变化率、耦合关系；诊断原始/投影动作 | 逐维饱和不足以保证联合可行；重新计算所有残差 |
| `controllers/common/fallback_supervisor.m` | 检查原EMS回退候选；无可行解向既有保护请求降载 | 不把违规回退标为安全；显式 hard_infeasible |
| `controllers/ecms/ecms_step.m` | 燃油图+电池等效燃油瞬时优化、SOC反馈等效因子 | 参数只在训练/验证轨迹选择，测试冻结 |
| `controllers/dp/solve_dp.m` | 完整已知循环上以SOC等状态离散动态规划 | 保存网格、阶段动作、终端SOC边界、不可行区和离散误差 |
| `controllers/dp/replay_dp.m` | 回放离线命令并经同一安全层 | 降阶最优≠原高保真全局最优；统计偏离与投影 |
| `tests/test_constraints.m` | 极端SOC、空可行集、切换、NaN/Inf、零转速等 | 不掩盖 infeasible；保护响应可追溯 |

DP 如果未对发动机状态、模式/切换和时延建足够状态，必须标为 **approximate offline DP reference**。它可以访问未来，不能直接视作可部署在线竞争方法，也不能无证明地当成严格性能下界。

## 4. 阶段 D：数据及训练

| 新文件 | 实现内容 | 防泄漏/验收 |
|---|---|---|
| `training/generate_dataset.m` | 由Existing/ECMS/DP及明确扰动生成轨迹；保存原始观测、动作、保护、元数据 | 专家动作可行性筛选，不学无标记的约束放松结果 |
| `training/split_trajectories.m` | trajectory_id及基础工况family分组；测试city/suburban/stress固定锁定 | 同一次仿真窗口和强相关派生轨迹不可跨集合 |
| `training/prepare_sequences.m` | 0.1 s采样、20–50点history、20–50点target；padding/mask | 先分轨迹再切窗；均值方差仅train估计；不跨轨迹拼接 |
| `training/train_mlp.m` | 当前状态→低维独立动作，安全层解算4参考值 | 特征范围一致；保存最佳val模型及损失 |
| `training/train_lstm.m` | 相同历史/目标的LSTM，MAE/Huber/加权MSE | 参数、优化器、epoch、提前停止、种子固定记录 |
| `training/train_transformer.m` | 相同历史/目标的Transformer；位置编码、因果输入、回归头 | 调参预算公平；不把真实未来target送入在线推理 |
| `training/train_ensemble.m` | 多seed训练Transformer集成并保存成员manifest | 训练和预测计算成本均记录 |
| `training/validate_predictor.m` | 按通道和预测步长统计MAE/RMSE；负载突变分组 | 输出真实预测与target，测试仅最终评估 |
| `training/calibrate_uncertainty.m` | 验证集校准集成方差/分位数覆盖率 | 不用测试循环拟合风险参数 |
| `datasets/<version>/manifest.json` | 数据版本、源模型hash、工况、扰动、划分、seed、单位、归一化 | 原始MAT与训练文件可溯源 |
| `tests/test_causality_and_splits.m` | 扰动未来输入检验当前输出不变；轨迹ID交集为空 | DP例外明确；预测器在t最多看到t |

泛化强度必须分开说明：以city/suburban扰动训练再测固定city/suburban只能证明扰动/轨迹留出，不足以单独证明未知工况族泛化。另留出完整循环族或独立未见工况作为外推评估；stress300若作为该集合则不参与训练或调参。

## 5. 阶段 E：MPC与风险方法

| 新文件 | 实现内容 | 验收 |
|---|---|---|
| `controllers/common/cem_mpc.m` | 0.1 s周期、H=20–30、256–512样本、10%精英、3–5轮；移位warm-start | 实测平均/最大/p95耗时；超0.1 s视为未满足在线预算 |
| `controllers/common/rollout_cost.m` | 燃油图、电池等效能量、跟踪、终端SOC、动作变化、启停/切段、违规 | 单位/代价尺度归一；已知模型状态与预测扰动分开 |
| `controllers/mlp_policy/mlp_step.m` | 调用已训练策略并投影 | 学习模型缺失报错，诊断推理耗时 |
| `controllers/lastvalue_cem/predict_lastvalue.m` | 只保持当前观测 | 与LSTM/Transformer相同目标4通道 |
| `controllers/lstm_cem/predict_lstm.m` | 历史→预测；共享投影、MPC与约束 | 端到端计时包含推理与投影 |
| `controllers/transformer_cem/predict_transformer.m` | Transformer预测适配 | 长度、归一化、单位一致 |
| `controllers/transformer_cem/risk_sensitive_step.m` | 多预测场景同一候选rollout，E[J]+lambda*Std(J)或预声明CVaR | 不能把输出方差直接当成本方差；记录场景数与额外时延 |
| `tests/test_controller_switching.m` | 8方法的ID切换、状态重置、共同总线、输出维数 | 未训练方法不标通过闭环验收 |
| `tests/test_short_closed_loop.m` | 依序30 s、完整city200、三工况 | 切换/制动/过载边界，保护次数与实际动作残差 |

初始迁移优先函数式可切换调度+固定接口；若 Variant Subsystem 更符合编译支持再采用 Variant。深度学习推理的 MATLAB Function/code generation 支持需要在 R2024b 目标环境逐层验证，不能预设所有训练层都能在 Simulink 内代码生成。正常仿真、加速、部署是三个独立能力级别。

## 6. 阶段 F：主实验、消融、鲁棒性与论文输出

| 新文件 | 内容 | 验收 |
|---|---|---|
| `evaluation/batch_experiments.m` | 3工况×8方法；随机方法至少5次、推荐10次 | 先串行通过，再按能力启用parsim；每worker独立状态/缓存 |
| `evaluation/build_ablation_matrix.m` | 去燃油图、去终端SOC、风险lambda=0、去历史、LSTM替换、完整风险方法 | 去燃油图需明确替代代理成本；lambda=0保持同ensemble和场景采样隔离风险项 |
| `evaluation/build_robustness_matrix.m` | seed重复与质量/SOC/阻力/坡度/负载未知扰动分别登记 | 参数扰动为所有方法共享配对场景；不能把seed方差等同物理鲁棒性 |
| `evaluation/aggregate_results.m` | 均值/std/样本数/失败数、必要时配对置信区间 | 不静默丢弃失败；未运行与未测量区分 |
| `evaluation/export_tables.m` | MAT/CSV/XLSX/LaTeX主表、消融表、鲁棒性表 | 主表含Cycle/Method/Fuel/EqFuel/ΔSOC/RMSE/Δd/耗时/违规 |
| `evaluation/plot_comparison.m` | SOC、累积燃油、速度、工作点、耗时、预测误差、损失图 | 原始点可追溯；保存绘图数据和导出设置 |
| `evaluation/validate_fairness.m` | 同模型hash、初值、cycle、约束、停止条件、代价公式审计 | 早停运行不与完整循环直接比较L/100km |
| `evaluation/run_acceptance.m` | 汇总用户12项验收与方法性能准则 | 未执行=未运行；失败给日志链接；不得虚构改善 |
| `README.md` | 已完成范围、环境、运行入口、数据与结果清单 | 随每阶段更新真实状态 |

统一指标定义：燃油图得到g/s，积分为g，除以1000与密度(kg/L)为L，再除实际里程km乘100；等效校正能量以电池净能量减少为正，先换为kg再为L，保持与实测燃油同单位。SOC若由模型输出百分数，应在数据适配层除100，输出表ΔSOC再乘100。传动效率必须基于明确定义的边界功率积分区间，发电/制动分别处理，不平均瞬时除零比值。违规同时保存事件次数、违规采样点数、持续时间和幅值，避免采样率改变次数。

## 7. 推荐执行闸门（后续入口尚待实施）

```matlab
% 以下为计划接口，阶段 A 不声称这些函数已经可运行。
paths = startup_ml_ems;
cfg = experiment_config;
build_emt_ml(cfg);
run_acceptance(cfg,"parameters_and_baseline");
run_experiment(cfg,load_cycle("city200"),"existing_grid",1);
generate_dataset(cfg);
train_mlp(cfg); train_lstm(cfg); train_transformer(cfg);
validate_predictor(cfg);
batch_experiments(cfg,"main");
batch_experiments(cfg,"ablation");
batch_experiments(cfg,"robustness");
export_tables(cfg);
```

每个闸门须记录修改文件、运行命令、真实测试、未解决问题。Fast Restart 仅在参数可调且工况/结构条件允许时启用；控制器结构变化可按方法分组编译。`parsim`在无并行工具箱时提供串行退路；不能把受限运行环境或旧缓存误判成算法故障。

API核对依据（MathWorks官方，查询2026-09-05）：[`setVariable`](https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.setvariable.html) 支持模型工作区定向覆盖；[`parsim`](https://www.mathworks.com/help/simulink/slref/parsim.html) 提供批量并行/串行及Fast Restart配置；[`setModelParameter`](https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.setmodelparameter.html) 记录标量 SimulationInput 的 Fast Restart 自 R2024a 支持。实施仍以本机 R2024b 实测为准，不使用文档中晚于R2024b的新接口。
