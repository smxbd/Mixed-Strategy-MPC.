# 阶段 A：原项目分析与改造前核验

日期：2026-09-05。范围：用户要求的阶段 A，读取实际项目、核对结构/算法/版本/依赖，并制定 B–F 文件级计划。没有修改原模型，没有开展新的轨迹仿真、机器学习训练或方法性能比较。

**结论：当前主模型可以在本机 MATLAB R2024b 中加载并编译；高层算法应命名为 Existing heuristic-grid EMS。它可以作为需要保留的原始基线，但不提供新系统所要求的硬安全保证。建议下一阶段先做等价重构和配对基线，再接新控制器。**

## 1. 实际验证及原文件保护

| 检查 | 结果 | 证据/限制 |
|---|---|---|
| 项目根目录原始文件 | 22个文件 SHA-256 全部保持一致 | `analysis/evidence/original_files_integrity_check.json`；包括模型、所有备份、MAT、旧MEX、slxc、图像与脚本 |
| 当前主模型版本 | R2024b / 24.2.0.2712019 | 文件头、包元数据及实际运行一致；用户描述的R2024a适用于另存的备份 |
| 安装运行环境 | MATLAB R2024b，PCWIN64 | 可执行程序 `D:\Matlab\Matlab R2024b\bin\matlab.exe` |
| 原模型精确副本加载 | 通过，39.938 s | 副本使用相同字节；未在原目录执行加载回调 |
| 原模型精确副本编译 | 通过，22.179 s | `feval('EMT',[],[],[],'compile')`，随后终止编译并关闭，未保存模型 |
| 控制器有效采样 | `[0.02,0]` s | 实测 `CompiledSampleTime`，不采用父虚拟子系统存储的10 s推测 |
| 控制器编译输入/输出 | 单个19元素输入；单个1×4输出 | CompiledPortDimensions：Inport `[1,19]`；Outport `[2,1,4]` |
| 旧32位MEX | 未使用 | 未拷贝 `EMT_sfun.mexw32`；`which('EMT_sfun')`为空；编译仍通过 |
| 30秒、city200完整、三工况仿真 | 未运行 | 属阶段B及以后，不能以编译替代 |
| 基线等价、ML训练、硬约束及性能改善 | 未验证 | 本阶段没有对应实验数据 |

运行证据保存在：

- `analysis/runtime/probe_20260905_155406/runtime_audit.json`：配置、许可测试、编译采样、端口维数。
- 同目录 `runtime_audit.mat`：含完整 MATLAB 对象的原始记录。
- 同目录 `matlab_batch.log`、`matlab_diary.txt`：原始运行输出及警告。
- 同目录的 `EMT.mdl`、`parameter.m`：隔离副本；运行产生的 `parameter.mat` 和缓存也留在该目录，不与原文件混用。

原回调为 `PreLoadFcn=parameter;`、`InitFcn=parameter;`、`StopFcn=save('result.mat');`。原 `parameter.m` 清空工作区、关闭图窗、绘图并保存参数。因此加载本身就有写文件副作用。本次使用独立目录、独立缓存、后台新进程和隐藏图窗；没有在原项目根运行 `parameter`。最初受限进程没有产生执行日志，后在获准的隔离运行中完成核验；这不是模型编译失败。

上述耗时是一次加载/编译耗时，**不是在线 EMS 计算耗时或实时因子**。原 `slprj` 未作为工作缓存使用，原目录未进行递归删除或迁移。

## 2. 实际结构、版本与依赖

当前OPC文本模型有274个System、2358个Block，顶层10个对象：Battery、Control Unit、Front Gear、Power Coupler（尾空格）、Rear Gear、Simulation Results、Vehicle dynamics、engine、motorA、motorB。详细SID、连线、Tag和库引用见 `model_topology_audit.md` 与机器可读 `analysis/evidence/topology_static.json`。

| 文件 | 核实版本 | 本次处理 |
|---|---|---|
| `EMT.mdl` | R2024b OPC文本包 | 精确副本加载/编译通过，原文件不变 |
| `EMT.mdl.r2024a` | R2024a OPC文本包 | 静态对比，保留 |
| `EMT.mdl.r2011b` | MDL Version 7.8 | 保留，不声称现代环境下已复现 |
| `EMT.mdl.r2015b` | MDL Version 8.6 | 原始兼容备份，保留 |
| `EMT.mdl.r2016b` | MDL Version 8.8 | 保留 |
| `EMTtest02.slx` | R2016b / MATLAB 9.1.0.441655 | 静态读取包信息，未替代当前主模型 |
| 两个 `.slxc` | 元数据R2019b | 历史缓存，未依赖 |

当前模型与R2024a备份的Stateflow chart_7规范化内容相同；同SID块直参变化主要是148处库版本和1处Scope配置。此结果不能当作跨版本数值等价证明。

MATLAB、Simulink、Stateflow、Simscape、Simscape Driveline、Simscape Electrical相关许可、Deep Learning Toolbox、Parallel Computing Toolbox的 `license('test',...)` 均返回1，`ver`也列出相应产品。基础模型编译已经实际通过；深度学习训练、GPU、并行池、各层的代码生成和Fast Restart尚未验证。CEM自行实现不必然依赖 Model Predictive Control Toolbox；部署/生成代码应另测所需工具链。

静态库引用：fl_lib 82、nesl_utility 55、sdl_lib 10、simulink 49、simulink_need_slupdate 6、powerlib_extras 1。仅见Stateflow的`sf_sfun`包装，无显式旧`EMT_sfun`引用或ModelReference块。

## 3. 高层控制器：十项核对结果

精确路径：

```text
EMT/Control Unit/Control/Power Distribution/Optimal Power Distribution/Optimization␠
SID 11353；␠代表真实的尾随空格。
```

父层有10个输入端口和4个输出端口，内部拼接成19维向量。原算法入口实际是 `function y=fcn(u)`，不能误接成19个独立Simulink输入端口。逐维来源、单位、公式和原MDL行号见 `optimizer_audit.md`；未改动的解码源码见 `analysis/evidence/optimization_original.m`。

| 核对项 | 结论 |
|---|---|
| 1 输入/输出 | `u=[Pe_com,pedal,ZD,stage,ne_act,ne_max,ne_min,no_act,Te_max,Te_min,TA_max,TA_min,TB_max,TB_min,PN_com,PN_max,PN_min,PZ_com,sd_ne]`；`y=[ne_ref,Te_ref,TA_ref,TB_ref]` |
| 2 经济转速 | 功率限0–1200 kW，硬编码Peg/neg插值；换段同步、踏板、实际转速和sd_ne修正；最终返回未加sd_ne的ne_ref0 |
| 3 候选生成 | 发动机20点，A/B各20点共400对；发动机候选按顺序搜索，遇到首个可接受Te退出，不是8000点全局最优 |
| 4 阶段关系 | 转速按stage<3、3≤stage<4、stage≥4分支；转矩仅按stage==3与其他分支。stage2是换段，不能当作稳态EVT1 |
| 5 电池约束 | 根据A/B机械功率及固定效率估算PN；判据主要作用于PN−PN_com，含3倍边界及逐级解除；不等于电池实测总功率硬约束 |
| 6 电机约束 | 上游转速推算及转矩查表；大踏板低速时转矩边界乘1.5；查表输入限幅不证明实际电机不过速 |
| 7 目标函数 | 以PN偏差/回收倾向和负输出转矩代理项评分；不读取fuel_map，无多步预测及终端SOC成本 |
| 8 无解策略 | 多层放宽PN、同号、转速方向判据，最后改罚函数；没有输出降级层级/不可行标志 |
| 9 采样 | 编译证实EMS为0.02 s；模型ode5固定步长0.002 s；sd_ne离散PI存储周期0.5 s |
| 10 下游 | 四参考经Rate Transition和Demux→全局Tag；Te/TA/TB由EVT/换段支路消费；ne_ref进入PI生成sd_ne，不是直接驱动一个统一转速执行器 |

当前19维不直接提供SOC、电压、电流、目标车速、坡度、阻力、用电负载、历史动作等全部新方法所需状态。新总线必须扩展观测，并保留19维适配器；不能仅把旧向量改名就声称统一接口完成。

核心静态问题：制动分支 `PN(i)` 使用发动机索引而非电机候选索引j；一层降级找到动作未设置成功标志；后层存在残留循环索引改写Te_ref；速度上下界可能出现空集合；候选内部补偿转速与返回转速不同；目标跨降级层尺度改变且J0不重置。**本阶段只登记，未修改；是否在指定轨迹触发还需构造测试和闭环记录。**

## 4. 参数、工况、日志与单位

`parameter.m`为GBK文本，341行，混合了车辆/发动机/电机/电池/传动参数、控制表、循环、绘图和保存；`plot_result.m`174行。两份MAT成功解析，172个公共数值变量一致。具体变量和值见 `parameters_cycles_audit.md` 及 `analysis/evidence/parameters_inventory.json`。

最关键的燃油口径：原表写入时是g/s，脚本39–42行将它转换并覆盖为 **g/kWh**。最终fuel_map为30×28，模型用转置表进行BSFC插值，再乘机械功率，转换体积流量时采用 **0.84 kg/L**。新目标必须明确BSFC→g/s→kg/L的转换；LHV和等效效率尚无集中、经确认的参数。零负载燃油和启动燃油也不能凭空补造后混称同一车辆基线。

| 通道 | 当前真实状态 | 后续处理 |
|---|---|---|
| city200 | 活跃0–200 s，0.1 s网格，速度0–50 km/h | 先保留原始速度公式和当前物理输入 |
| suburban400 | 注释中0–400 s，速度0–120 km/h | 恢复独立循环；核对v_act>120提前停仿真条件 |
| stress300 | 不存在 | 新建并通过实际日志确认高负荷、回收和切段 |
| road_resistance | 最终输出常数0.045；fg_map未被模型使用 | 新模型接通动态输入，所有方法共同使用 |
| grade | 最终输出0；动力学用sin(angle)，坡度角应为弧度 | 显式单位；不能将坡度百分数直接喂入sin |
| steering | Wheel只到显示记录，未进入车辆动力学 | 标明无物理作用；若需生效，必须补接口并验证 |
| aux_power | Time_ele/ele_map查表接入实际支路 | 保留其滤波/饱和与时间轴，不能随意拉伸 |

历史result.mat主日志是0–1500 s、0.2 s间隔、7501点，却携带200 s速度循环；tout只含1498.002–1500 s最后1000点。部分Z机日志只有t=0单点。因此历史结果只能作为来源不完全的新实验前诊断，不能直接充当本次city200复现或新训练数据。逐信号必须使用各自时间轴。

原plot_result还会裁剪发动机绘图点到外特性、把电机工作区显示边界扩到±7000 rpm（原参数±6000），以及直接计算可能除零的瞬时效率。新评价不能把这些图当作无越界证明，必须保留原始观测并计算约束残差。

## 5. 编译警告与优先风险

编译通过同时存在：若干motorZ/Viewer的From没有对应Goto；部分Goto无人消费；Grade、Ground、Pedal及ElectricPower中的分支输出未连接；6处PID理想导数接非连续/不可微信号警告；左右Steering Resistance Switch的uint8阈值0.5量化为1。详见原日志，不应在等价重构阶段通过关闭全部诊断掩盖。

| 优先级 | 风险 | 下一阶段动作 |
|---|---|---|
| P0 | 初始化/停止回调覆盖工作区及原结果 | 只改新副本回调；所有运行使用唯一目录 |
| P0 | 原启发式放松边界，回退未必安全 | 所有回退动作再检验；硬可行集为空时记录并调用原保护/降载 |
| P0 | fuel_map单位误用、SOC百分数误用 | 集中单位适配，解析积分测试，未确认参数不计算论文等效燃油 |
| P1 | 原算法疑似缺陷修复会改变基线 | 先原样封装；修正版另行命名和对照 |
| P1 | 多通道定义存在但未接入物理模型 | 逐通道激励测试，不以生成曲线替代接线验证 |
| P1 | 0.02→0.1 s改变控制律和比较条件 | 原周期等价复现；共同周期对照明确另列；保留0.002 s物理步长 |
| P1 | 高保真DP状态爆炸、预测误差、CEM超时 | 先验证降阶模型；DP标为近似离线参考；实测完整在线时延 |
| P1 | 相邻窗口及派生轨迹泄漏 | 先按完整轨迹/工况族划分再切窗，归一化只用train |
| P2 | 日志截断、图示裁剪、提前终止 | Dataset+自身时间轴、保留异常点、统一停止与失败处理 |

## 6. 本次新增文件与后续执行

已新增：

- `docs/STAGE_A_REPORT.md`：本汇总报告。
- `docs/model_topology_audit.md`、`optimizer_audit.md`、`parameters_cycles_audit.md`：三份有行号/SID证据的专项审计。它们的“未运行MATLAB”仅描述各自静态分析方法；本报告补充了独立运行结果。
- `docs/FILE_LEVEL_IMPLEMENTATION_PLAN.md`：B–F每个新文件的职责、接口、依赖、验收和实验公平性约束。文件名以该总计划为准，专项报告中的名称为建议。
- `analysis/extract_topology.py`：可重跑的只读模型清点，实际解析293个XML部件成功。
- `analysis/probe_original_model.m`：隔离加载、编译、依赖和采样探针；不执行轨迹仿真。
- `analysis/run_stage_a_audit.ps1`：重复审计入口，每次新建唯一副本目录并核对原文件哈希。
- `analysis/evidence/`：原算法源码、变量清单、模型清单、哈希及运行目录索引。
- `analysis/runtime/`：真实加载/编译记录、隔离副本和该次产生的缓存。
- `README.md`：交付入口与运行说明。

本次未生成`EMT_ML.slx`，未建立可运行的8种控制器，未生成训练权重/主实验/消融/鲁棒性性能表。不会用空壳模型、伪随机指标或历史结果冒充这些交付。

重复审计可在项目根运行：

```powershell
powershell -NoProfile -File .\ml_ems\analysis\run_stage_a_audit.ps1
python .\ml_ems\analysis\extract_topology.py
```

本次成功运行使用的是runtime目录保存的探针快照；随后新增的启动封装和目录防误用检查仅完成静态检查，未为文档更新重复整套模型编译。原始成功日志及快照完整保留。若受限环境阻止MATLAB正常启动，需要允许本机MATLAB写入其正常运行环境；不能跳过审计而标通过。

下一阶段推荐顺序：参数纯函数及原变量适配→冻结原样算法→从已验证源保存新SLX并清理副本回调→相同条件原/新30 s配对比较→完整city200→启用共同多通道工况及三循环批量→ECMS/DP→数据与ML。更细的文件、接口、测试容差和实验矩阵见文件级计划。
