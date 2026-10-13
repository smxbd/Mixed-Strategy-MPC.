# Rming's-advice

这是基于 `EarlyVersion` 的模型修改建议分支，用于记录 Riming 建议后的 EMS、ECMS、连续性 DP 和 CEM-MPC 修改，并恢复历史 Transformer/LSTM 候选权重进行对照仿真。

远程分支：`Rming's-advice`

远程仓库：[smxbd/Mixed-Strategy-MPC.](https://github.com/smxbd/Mixed-Strategy-MPC.)

## 分支内容

本分支包含以下改动：

- 统一电池等效燃油率、SOC 反馈和 ECMS 因子计算。
- 在连续性 DP 和 CEM-MPC 中使用电压相关的电池功率约束。
- 改进 CEM-MPC 的功率探索范围、SOC 偏置热启动和精英样本拟合。
- 修正预测器输出与运行时域之间的物理时间对齐。
- 修正 Phase-D2 八维输入归一化统计量。
- 提高 DP 的 SOC 和电池功率网格分辨率。
- 恢复 `ml_ems/models/transformer_1.mat`、`ml_ems/models/lstm_1.mat` 和 Transformer 参考配置。

历史权重是候选恢复文件，没有在本分支重新训练。训练数据、网络执行栈和运行配置存在差异，因此结果用于工程诊断，不能单独作为 Transformer 与 LSTM 的架构优劣结论。

## 环境

- MATLAB R2024b 或兼容版本
- Simulink
- 项目模型运行所需的 MathWorks 工具箱
- Python 3.10 或兼容版本（仅在重新生成图表时需要）

从仓库根目录启动 MATLAB，并初始化路径：

```matlab
root = pwd;
addpath(fullfile(root, "ml_ems"));
startup_ml_ems();
```

不要从 `ml_ems` 子目录启动，因为循环、模型和结果目录都按仓库根目录解析。

## 基础检查

```matlab
startup_ml_ems();
test_core();
test_power_accounting();
```

可单独检查恢复的预测器和参考配置：

```matlab
run(fullfile(root, "figure_outputs", "inspect_predictor_artifacts.m"));
```

## 三控制器仿真

完整入口为：

```matlab
run(fullfile(root, "figure_outputs", "run_three_controller_figures.m"));
```

该批次固定 `seed=1`，包括三种驾驶循环和三种控制器：

| 控制器 | 编号 |
|---|---:|
| Existing EMS | 1 |
| LSTM CEM-MPC | 6 |
| Transformer CEM-MPC | 7 |

运行结果写入 `ml_ems/results/`。结果目录属于本地仿真产物，通常不应提交到 Git。

## 已保存的图表和数据

已提交的交付物位于 `figure_outputs/three_controller_20261012/`：

- `*_tracking_soc_fuel.svg/pdf`：速度、SOC 和累计油耗轨迹。
- `*_metrics.svg/pdf`：单工况指标比较。
- `*_transformer_components.svg/pdf`：Transformer 工况下的动力系统量。
- `all_cycles_metrics.svg/pdf`：三工况汇总。
- `comparison_metrics.csv`：九次仿真的指标表。
- `data/*_trajectories.csv`：保留完整原生采样点的轨迹表。
- `analysis.md`：图表分析和结果解释。
- `data_manifest.json`：原始 MAT 运行文件的名称、采样数和哈希记录。

重新绘图时，先确保 `figure_outputs/three_controller_20261012/data/` 中存在对应的运行数据，再执行：

```bash
python figure_outputs/plot_three_controllers.py \
  --batch figure_outputs/three_controller_20261012
```

脚本会同时导出 SVG、PDF、PNG 和 TIFF；Git 提交中保留 SVG/PDF 以及轻量 CSV，避免把大体积图片和 MAT 缓存写入仓库。

## 单次结果摘要

以下结果来自固定随机种子下的九次诊断批次，单位与 `comparison_metrics.csv` 一致：

| 工况 | 控制器 | 速度 RMSE (km/h) | 油耗 (L) | SOC 变化 (百分点) |
|---|---|---:|---:|---:|
| city200 | Existing | 0.776 | 3.927 | -0.114 |
| city200 | LSTM | 17.893 | 0.144 | -14.284 |
| city200 | Transformer | 0.874 | 3.737 | -1.276 |
| suburban400 | Existing | 7.197 | 21.245 | +0.290 |
| suburban400 | LSTM | 64.000 | 0.086 | -20.896 |
| suburban400 | Transformer | 8.110 | 19.113 | -5.578 |
| stress300 | Existing | 10.461 | 13.109 | +0.407 |
| stress300 | LSTM | 33.634 | 0.639 | -12.247 |
| stress300 | Transformer | 12.565 | 11.733 | -0.657 |

低油耗必须结合 SOC 变化、速度跟踪误差、可行性约束和实际完成距离一起判断。当前 Transformer 结果仍出现较多物理约束超限和回退行为，不能直接视为相对于 EarlyVersion 的合格提升；LSTM 的低油耗也伴随明显放电和较大的跟踪误差。

## 复现注意事项

- 预测器按训练采样周期和运行采样周期进行物理时间插值，不把 20 步历史输出直接压缩成 10 步。
- 三控制器批次使用同一随机种子，便于配对比较；单个 seed 不提供置信区间或显著性检验。
- 高速或阶跃参考可能超出车辆能力，跟踪误差需要与动力学可行性一起解释。
- `restored_predictor_manifest.json` 记录了权重哈希、训练周期和恢复状态。
