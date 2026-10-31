# Mixed-Strategy MPC — 源码快照（2026-10-31）

混合动力车辆能量管理 MATLAB/Simulink 项目，包含原有 EMS、LSTM 和 Transformer 控制策略，以及发动机转矩、电机转速和功率约束相关实现。

本分支保存当前工作目录的有效源码和主模型。源码与本地版本逐文件校验一致。

## 文件范围

- `ems_project_app.m`：仿真操作界面。
- `EMT.mdl`、`ml_ems/models/EMT_ML.slx`：基准模型与当前主模型。
- `ml_ems/controllers/`、`config/`、`cycles/`：控制器、配置和工况。
- `ml_ems/training/`、`evaluation/`、`continuation/`：训练、仿真及评估程序。
- `ml_ems/tests/`、`analysis/`、`tools/`：检查、分析和辅助脚本。
- `parameter.m`、`parameter.mat`、`ml_ems/config/transformer_reference_config.mat`：运行输入参数和配置，属于程序依赖。

图件、仿真结果、训练数据、训练权重、日志、审计报告和历史备份不在本快照中。源码中的绘图及导出函数仍保留，供运行时调用。

## 使用

环境：MATLAB R2024b、Simulink、Simscape、Deep Learning Toolbox、Optimization Toolbox。以项目根目录为 MATLAB 当前目录：

```matlab
addpath('ml_ems');
startup_ml_ems;
ems_project_app;
```

LSTM/Transformer 仿真需要另行提供匹配的 `ml_ems/models/lstm_1.mat` 和 `transformer_1.mat`；Transformer 配置还会校验权重与模型哈希。权重不随本次源码上传发布。

模型重建和部分历史回归脚本依赖本地原始模型目录、审计清单或历史结果；这些文件未随本次源码上传发布。此分支保留原实现，不修改控制逻辑或本地路径。

默认仿真输出写入 `ml_ems/results/`，已由 `.gitignore` 排除。本次发布仅验证源码完整性及上传文件范围，未重新运行完整仿真。
