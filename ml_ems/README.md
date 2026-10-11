# ML EMS 阶段B框架

本目录是在原始项目副本上新增的实验框架。原始 `EMT.mdl`、参数脚本和 `parameter.mat` 快照位于仓库根目录；运行缓存和临时日志不纳入版本控制。

```matlab
root = fileparts(fileparts(mfilename('fullpath')));
cfg = experiment_config(root,'Seed',20260906);
build_city200('Save',true,'OutputDir',cfg.cycles_dir);
build_suburban400('Save',true,'OutputDir',cfg.cycles_dir);
build_stress300('Save',true,'OutputDir',cfg.cycles_dir);
```

阶段B已完成参数、循环和结果接口；Simulink 基线复现需要在安装 MATLAB/Simulink 的环境中运行，当前环境未执行模型仿真。
