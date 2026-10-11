# 续作交接：2026-09-06

## 用户最新要求

因额度即将耗尽，先总结，便于下次继续。本轮不再启动新实验。已经启动的 MATLAB 主批次保留运行，不要在下次进入时盲目重新启动。

## 项目与环境

项目根目录：`C:\Users\LAPTOP1210\Desktop\张东好(hun)\Optimal1103_for_Matlab2015b(好哥毕业模型程序无问题)`。
MATLAB：`D:\Matlab\Matlab R2024b\bin\matlab.exe`；Python：`D:\Anconda3\python.exe`。

原始需求附件：`C:\Users\LAPTOP1210\.codex\attachments\c3fe500f-845c-4da0-9bbc-3fc2595074ac\pasted-text.txt`。

用户已授权完成原需求全部剩余阶段。只能修改 ml_ems 新增项目，保留原模型、驾驶员、模式与底层保护。最新规则禁止主动派子代理，除非用户明确要求。MATLAB 启动通常需工具沙箱升级；之前自动审批偶因额度限制拒绝，不得绕过。

原始 22 个文件上次 SHA256 核对全部不变。证据：`ml_ems/analysis/evidence/original_files_integrity_20260906.json`。

## 当前后台任务：下次首先检查

- 启动入口：`run_residual_main`。
- MATLAB launcher PID：28000；worker PID：17984（仅为本次记录，下一次必须重新检查，不能盲用 PID）。
- 启动日志：`ml_ems/results/job_20260906_144826_b681b866/matlab.log`。
- 最近启动指针：`ml_ems/results/latest_job.json`。
- 主批次目录：`ml_ems/results/main_shard1_20260906_144935_3c9dc7ac`。
- 批次版本：`ems-r2024b-v7-residual-power-accounting`。
- 源码/SLX/权重快照：`ml_ems/results/source_snapshot_20260906_144838_aeffc98c`。已用 Python 核对 33 个控制、配置、模型、权重文件，零不一致。
- 当前队列：三工况 × 八方法，共 24 项；结束后会自动 aggregate_results。不会自动修复 MLP，也不会自动启动消融/种子/泛化。

本交接写入时 city200 八项已尝试，七项完成、一项失败，批次已进入 suburban400。后续状态可能已经更新，以 catalog.mat、results.csv 和各 run.mat/status.json 为准。

| MethodID / 方法 | city200 RMSE km/h | 等效油耗 L/100km | 状态 |
|---|---:|---:|---|
| 1 原控制器 | 0.7972258 | 389.653997 | completed |
| 2 近似离线 DP | 1.6480222 | 395.726390 | completed |
| 3 ECMS | 0.7565176 | 378.143039 | completed |
| 4 MLP | NaN | NaN | failed，类型问题 |
| 5 Last-value CEM | 0.7910720 | 367.276344 | completed |
| 6 LSTM CEM | 0.7752128 | 366.052060 | completed |
| 7 Transformer CEM | 0.7727572 | 365.932928 | completed |
| 8 Risk-sensitive Transformer | 0.7713400 | 368.722516 | completed |

以上不是验收通过结论。当前 Accepted 均为 false。存在物理超限、命令不可行、部分计算峰值超时，且新方法终端 SOC 相对基线有差异。不得仅按这一次城市油耗排名宣称最终优势。

## 本轮已完成的修正

1. 修正 CEM 的附件负载重复计入。`observation_features` 的第二通道已包含 aux，原 PN_com = 电池请求 − PN0 − aux；现在 rollout 的电池需求为 feature(2)+PN0−enginePower，轮端可用功率扣除 aux 与 PN0 各一次。新增 `demand_power_balance.m` 和 `test_power_accounting.m`，功率守恒回归通过。特征数值/归一化未变，因此原残差权重可继续使用。
2. 旧 v6 批次 `main_shard1_20260906_143842_02d4add5` 因上述问题主动停止，仅完成基线和 DP；已写 interruption.json，旧数据保留，不混入 v7。
3. 30 秒 v7 残差模型预检完成，基础测试、结果统计测试、功率守恒测试通过；完整计时字段存在。预检目录：`city200_m7_s1_20260906_144838*` 附近（应从日志/实际目录核对，勿猜路径）。之前 v6 预检实际目录为 `city200_m7_s1_20260906_143738_481eefd3`。
4. `snapshot_source` 现在同时复制并哈希实际使用的 SLX 和五个权重，而非仅复制 m 文件。
5. 新增 `resume_residual_main.m`：校验控制/配置/SLX/权重快照后跳过 completed 项。尚未实际执行中断续跑验证；源哈希数据已独立检查。
6. 图表后处理改为显式指定验证目录，不再选择日期最新目录。训练曲线按模型分别显示并包含验证曲线；工作点加入 BSFC 等高线并优先使用高频物理观测。图像输出放入新目录，保留源 run 路径。上述新绘图代码尚未在 MATLAB 实际运行/视觉核验。
7. 新增 `finalize_residual_results.m`：汇总 v7 主表、训练/预测图、发动机/电机工作点、初始化/决策/安全检查计时附表。尚待执行。
8. 新增运行指南 `ml_ems/docs/EXECUTION_GUIDE.md`。

## 必须修复：MLP 单精度输入错误

city200 MLP 在 S-Function Start 的预热阶段报错：QUADPROG 要求 f、X0 为 double。MLP predict 返回 single，传播至 project_qp。

当前正在运行的控制源码尚未修改，避免改变活动批次。待当前批次完全结束后，将 `ml_ems/controllers/ems_step.m` 的 MLP 分支：

`p=predict(a.net,z); p=p.*a.sigmaY+a.muY;`

改为：

`p=predict(a.net,z); p=double(p.*a.sigmaY+a.muY);`

这是接口精度修复，其他方法分支不变。必须保存补丁前文件和新源码快照，保留已完成运行的原 cfg/source_snapshot，明确记录实现补丁；不要把旧运行的来源重标为新快照。先测试 MLP 预热和 30 秒，再补跑三工况失败项目。

## 已准备但未启动的后续入口

- `complete_residual_suite.m`：批次结束后应用上述精度补丁，运行基础测试及 MLP 预热；保存新快照；补跑未完成主实验；生成图表；再串行跑消融、五随机种子和泛化。此入口尚未执行或完整验证，下次先审查并按上文做 30 秒 MLP 检查。它使用同一算法实验 cohort v7，通过 implementation_patch 与每次运行的 source_snapshot 区分类型补丁。
- `tools/continue_after_main.ps1`：等待给定 launcher 退出后启动 complete_residual_suite。仅编写，**未启动**。不得把它描述为已经排队或已经在运行。
- 消融 18 项、种子鲁棒性 60 项、物理泛化 24 项尚未由本轮启动。
- 当前机器约 16.89 GB RAM，运行一个 MATLAB 时曾剩约 3.16 GB；继续串行，尚未验证 parsim/Fast Restart，不要为了快而直接同时启动多个重型 MATLAB。

## 权重与预测证据

默认 experiment_config 版本为 `ems-r2024b-v7-power-accounting`，仍指向 `models/trained` 初始权重。主实验入口显式覆盖版本与权重目录：

`ml_ems/results/residual_training_20260906_143055_b35599be/models`。

其中有 MLP_1（沿用原策略）、LSTM_1、Transformer_1/2/3。原权重未覆盖。

独立验证结果：`ml_ems/results/prediction_validation_20260906_143127_e9cf542f`。全预测窗口 RMSE：Last-value 车速 1.1168、功率代理 91.228；残差 LSTM 0.9992、93.694；残差 Transformer 0.7106、98.225。车速改善，功率代理未改善，不得宣称所有目标预测均优。

## 仍未通过/尚待完成

- 零硬约束、实时性和全工况验收。启动时原系统也有同样的 80 A 研究限值超限，未删除样本或抬高限值。
- MLP 修复补跑，完整主实验收尾。
- 消融、五种子鲁棒性和物理泛化实测及表格。
- 新图表代码实际运行、渲染与视觉检查。
- 转向 Wheel 仅日志关联，未验证实际物理通路；不得声称完成转向泛化。
- DP 为降阶 SOC 网格离线近似参考，不是全模型最优下界。
- 训练数据仍是初始 6 条训练 + 2 条验证完整扰动轨迹，专家质量有限；标准测试工况没有加入训练，但基工况族重叠已声明。
- 80 A、电池等效热值/效率、简化电机效率与动态平衡余量为研究假设或近似，不能视作车辆标定及安全认证。

## 下次操作顺序

1. 读取本文件和最新 job/log/catalog；检查 MATLAB 是否仍活跃。活跃时不要重复启动或修改控制代码。
2. 若主批次已经结束，核对 24 项状态及具体错误；保存阶段结果。
3. 修复 MLP 类型问题，先做 30 秒实测，再补跑；核对实际来源快照。
4. 跑并检查 finalize_residual_results 的图表；之后串行完成消融、五种子、泛化。新入口未经完整验证，不要假定执行成功。
5. 所有失败/提前停止/未运行项继续保留 NaN 或明确状态。最终报告如实列出未通过项，不把 completed 等同 accepted。
