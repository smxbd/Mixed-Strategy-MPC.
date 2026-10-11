# 本轮完整主实验进度

当前批次：`results/main_shard1_20260906_144935_3c9dc7ac`。

当前版本：`ems-r2024b-v7-residual-power-accounting`。代码、模型和权重快照已保存，并核对 33 个控制/配置/模型/权重文件，无哈希不一致。

附件负载重复计入问题已修正，功率守恒回归已通过。旧 v6 批次在完成基线与 DP 后停止，已有数据保留，并写入 interruption.json。

截至本记录写入，city200 的基线、DP、ECMS、Last-value CEM、LSTM CEM 和 Transformer CEM 均已完成。MLP 因单精度网络输出不满足 quadprog 双精度输入要求而失败，尚待类型转换修复及补跑。风险敏感版本和另外两工况仍在批量队列中。

已有数据只支持单次城市工况比较，不能代替全部验收或多种子统计。主表随每个运行自动更新；以该批次 results.csv 和各 run.mat/status.json 为准。

恢复入口 resume_residual_main 已编写，并核对其所需快照数据；尚未实际执行中断续跑测试。调用前必须确认上一批进程已经结束。

图表后处理入口 finalize_residual_results 已补齐训练/验证图、工作点与计时附表，尚待批次结束后实际运行和视觉核验。
