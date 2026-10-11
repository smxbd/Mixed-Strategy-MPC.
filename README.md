# EarlyVersion

这是 revision20 Existing 基线的 MATLAB/Simulink 控制器重构程序包。仓库当前只发布程序、配置、模型源文件和说明文档；运行日志、图片、仿真结果、训练权重和 MATLAB 缓存不包含在 GitHub 版本中。

## 环境要求

- MATLAB R2024b 或兼容版本
- Simulink
- 运行具体模型或训练流程时，需要项目原本依赖的其他 MathWorks 工具箱
- Windows 用户建议使用 MATLAB 自带的 `matlab -batch` 或 MATLAB 图形界面运行

## 获取代码

```bash
git clone https://github.com/smxbd/-.git EarlyVersion
cd EarlyVersion
```

在 MATLAB 中把仓库根目录设为当前文件夹。不要直接从 `ml_ems` 子目录启动，因为程序需要通过根目录定位原始 `EMT.mdl` 和参数脚本。

## 初始化 MATLAB 路径

```matlab
root = pwd;
addpath(fullfile(root, "ml_ems"));
paths = startup_ml_ems();
cfg = experiment_config(root);
```

`startup_ml_ems` 会加入控制器、循环、评价、训练和测试目录；`experiment_config` 会建立本地生成循环、数据和结果目录，并初始化基线参数。

## 生成并检查驾驶循环

```matlab
cfg = experiment_config(pwd);
city200     = build_city200('Save', true, 'OutputDir', cfg.cycles_dir);
suburban400 = build_suburban400('Save', true, 'OutputDir', cfg.cycles_dir);
stress300   = build_stress300('Save', true, 'OutputDir', cfg.cycles_dir);

validate_cycle(city200);
validate_cycle(suburban400);
validate_cycle(stress300);
```

## 运行核心程序检查

```matlab
startup_ml_ems();
test_core();
```

该检查覆盖燃油单位、循环长度、确定性扰动、控制器约束投影和确定性 CEM-MPC。若 MATLAB 报缺少工具箱或模型文件，应先补齐对应依赖。

## 运行完整三控制器仿真

完整入口是根目录的 `run_full_three_controller_batch.m`，控制器编号为：1 Existing、7 Transformer、6 LSTM。运行前必须补回与实验记录匹配的运行依赖：

- `ml_ems/datasets/tped60d12a_aa1c_4f8a_8adf_7dac1f869816/training_config.mat`
- `ml_ems/models/trained/` 下的 LSTM/Transformer 权重
- 与权重对应的 `EMT_ML.slx` 和参数快照

补齐后，在仓库根目录运行：

```matlab
run('run_full_three_controller_batch.m');
```

结果会写入 `ml_ems/results/`，批处理摘要会保存为 `full_three_controller_batch.mat`。这些结果文件默认属于本地运行产物，不应提交到程序仓库。

## 运行单次轻量接口

`run_experiment` 也支持不启动 Simulink 的旧式控制器接口。调用方需要提供循环结构体、控制器函数句柄和选项结构体：

```matlab
cycle = build_city200();
opts = struct('initial_soc', 60);
controller = @(cycle, k, state) zeros(1,4);  % 示例控制器
out = run_experiment(cycle, controller, opts);
```

该接口用于检查循环和控制器调用链，不代表完整车辆动力学仿真。

## 结果和图片

结果图由保存的 `run.mat` 日志生成。程序仓库不包含这些日志和图片；如果已有本地结果，可调用：

```matlab
reproduce_reference_figures(root, fullfile(root, 'reproduced_figures'));
```

函数位于 `ml_ems/evaluation/reproduce_reference_figures.m`。它需要九个完整仿真结果目录，缺少日志时只能先运行完整仿真或从实验归档恢复结果。

## 常见问题

- **找不到 `training_config.mat`**：这是完整 Transformer/LSTM 延续仿真所需的实验配置，不属于当前程序-only 发布包。
- **找不到训练权重**：从对应实验归档恢复 `ml_ems/models/trained/`，并确认权重与 `transformer_runtime_policy.json` 的哈希一致。
- **找不到 `EMT.mdl`**：必须从仓库根目录启动，或把原始模型放回根目录。
- **生成了大量缓存**：删除 `slprj/`、`ml_ems/results/` 下的临时目录；仓库的 `.gitignore` 已忽略常见 MATLAB 缓存和日志。
