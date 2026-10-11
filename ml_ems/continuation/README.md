> 已暂停：当前基线批次结束，MATLAB 已退出。9 项中 3 完成、6 失败、0 验收通过。最新完整状态见 `C:\Users\LAPTOP1210\Documents\Codex\2026-09-06\files-pasted-by-the-user-matlab\outputs\本次执行与暂停总结_20260907.md`。以下记录保留执行过程。

# 2026-09-07 续执行记录

开发目标为本 Documents 副本。桌面原项目保持未修改。

## 已完成并实测

- 已核对当前 EMT_ML 与 Existing 等价性验证记录的 SHA-256 一致。
- 已审计历史主批次表，共 72 行目录记录；不是 72 次独立完成实验。保留其中 Desktop 路径，不改写来源。
- 新增 continuation_config / run_continuation_experiment / compute_continuation_metrics，兼容副本已变化的配置、运行和工况接口。
- 动作布局/非有限值比较、功率守恒、结果统计回归通过。
- MLP double 转换原已存在；30 秒真实预检确认不再发生 QP single 输入错误。
- Existing 30 秒 RMSE 0.614243 km/h；MLP 0.765359 km/h。MLP 最大决策 0.0442371 s，初始化 6.2969842 s，安全回调最大 0.0121948 s。17 次组合约束违反，物理超限仍在；不是安全验收通过。
- 首轮冻结预测器 city200 独立测试完成。功率代理 RMSE：Last-value 73.0074、LSTM 122.6724、Transformer 100.3078 kW。速度 RMSE：1.80596、7.30854、5.61033 km/h。首轮权重不满足闭环准入。

## 正在执行和待验证

- v3 传统基线批次：Existing、因果网格 ECMS、SOC 降阶 DP，三个完整工况。city200 Existing 已完成并从原文件恢复；以最新日志、run/status 和 catalog 为准。
- ECMS 采用燃油 g/s 加 SOC 自适应电池等效燃油 g/s；约束不允许的候选排除，无可行候选退回公共安全层。研究参数保留自已验证运行配置。
- DP 增加未截断功率需求可行性检查，仍只是 SOC 状态的近似规划，不能称全模型最优下界；不可行不生成伪造闭环指标。
- 新增 runtime.diagnostics，列为时间、是否决策、动作残差、当前状态残差、计时。保留原 62 列 trace 与组合残差，后处理另算动作约束和状态超限。该变更正在基线中验证。
- 加权残差训练入口已编写，尚未运行。只用已保存训练/验证轨迹；训练上五分位速度变化、高负载样本整数复制，实现权重 1–3 的 MSE；计划 1 个 LSTM 与 3 个独立 Transformer。首轮权重不覆盖。

## 继续入口

在 MATLAB 添加 ml_ems 路径后执行 startup_ml_ems。运行入口在 ml_ems/continuation。

1. 先检查 continuation_baselines_recovered_20260907.log 及 MATLAB 进程；不要重复启动批次。
2. 基线结束后检查所有 run/status、物理超限和分离诊断，并完成其余固定工况预测评估。
3. 运行 train_continuation_residuals(project_root)，完成独立固定和未见参数评估，不能仅凭验证集进入学习闭环。
4. 只有满足预测门槛后再做学习方法主实验、消融、5 种种子、泛化与最终图表。

失败尝试日志保留：首次基线工况结构体接口不兼容、第二次目录结构体初始化失败、初次独立测试旧路径失效及表行初始化失败。已修复并恢复成功数据，不把失败重写为通过。
