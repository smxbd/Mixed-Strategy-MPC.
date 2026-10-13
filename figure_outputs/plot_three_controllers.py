"""Plot a fixed, complete nine-run batch, retaining all native samples."""
from pathlib import Path
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET

from make_rming_figures import read_run, plt, np, pd

plt.rcParams.update({'font.family': 'sans-serif',
                     'font.sans-serif': ['Arial', 'DejaVu Sans', 'Liberation Sans'],
                     'svg.fonttype': 'none', 'pdf.fonttype': 42,
                     'font.size': 7, 'axes.labelsize': 7,
                     'xtick.labelsize': 6, 'ytick.labelsize': 6})
COLORS = ['#484878', '#42949E', '#B64342']
METHODS = ['Existing', 'LSTM', 'Transformer']
LABELS = ['Existing EMS', 'LSTM CEM-MPC', 'Transformer CEM-MPC']
CYCLES = {'city200': 200, 'suburban400': 400, 'stress300': 300}


def save(fig, base):
    fig.savefig(base.with_suffix('.svg'), bbox_inches='tight')
    fig.savefig(base.with_suffix('.pdf'), bbox_inches='tight')
    fig.savefig(base.with_suffix('.png'), dpi=300, bbox_inches='tight')
    fig.savefig(base.with_suffix('.tif'), dpi=600, bbox_inches='tight')
    plt.close(fig)


def label_axes(axes):
    for ax, letter in zip(np.asarray(axes).ravel(), 'abcdefghijkl'):
        ax.text(-0.12, 1.03, letter, transform=ax.transAxes,
                fontweight='bold', fontsize=8)
        ax.grid(True, color='#D8D8D8', lw=0.4, alpha=0.6)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--batch', type=Path, required=True)
    args = parser.parse_args()
    out = args.batch
    rows, provenance = [], []
    all_runs = {}
    for cycle, duration in CYCLES.items():
        runs = []
        for method in METHODS:
            path = out / 'data' / f'{cycle}_{method}.mat'
            run = read_run(path)
            assert abs(run['time'][-1]-duration) < .021, path
            # Existing EMS has NaN in unmeasured computation-time fields.
            # Validate all plotted observations without excluding any rows.
            assert np.isfinite(run['trace'][[19,20,21,38],:]).all(), path
            runs.append(run)
            metrics = dict(run['metrics'])
            metrics.update(cycle=cycle, controller=method,
                           final_time_s=run['time'][-1])
            rows.append(metrics)
            provenance.append({'data': path.name, 'samples': len(run['time']),
                               'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
            q = run['trace']
            pd.DataFrame({'time_s':run['time'], 'reference_kmh':q[19],
                          'speed_kmh':q[20], 'SOC_percent':q[21],
                          'fuel_L':q[38]-q[38,0], 'engine_rpm':q[4],
                          'engine_kW':q[31], 'battery_kW':q[34]}).to_csv(
                out/'data'/f'{cycle}_{method}_trajectories.csv', index=False)
        all_runs[cycle] = runs
        fig, axes = plt.subplots(3,1,figsize=(7.2,5.6),sharex=True)
        for method, color, run in zip(LABELS,COLORS,runs):
            t,q = run['time'], run['trace']
            for ax,y in zip(axes,[q[20],q[21],q[38]-q[38,0]]):
                ax.plot(t,y,color=color,lw=.85,label=method)
        axes[0].plot(runs[0]['time'],runs[0]['trace'][19],
                     color='#272727',ls='--',lw=.7,label='Reference')
        for ax,title in zip(axes,['Speed (km/h)','SOC (%)','Cumulative fuel (L)']):
            ax.set_ylabel(title)
        axes[0].legend(loc='lower left',bbox_to_anchor=(0,1.10),
                       ncols=4,fontsize=6)
        axes[-1].set_xlabel('Time (s)')
        label_axes(axes)
        fig.suptitle(f'{cycle} | current branch, historical predictor weights',fontsize=9)
        fig.tight_layout(rect=(0,0,1,.93))
        save(fig,out/f'{cycle}_tracking_soc_fuel')

        fig,axes=plt.subplots(2,2,figsize=(7.2,4.5))
        specs=[('RMSE_kmh','Speed RMSE (km/h)'),('fuel_L','Fuel (L)'),
               ('delta_SOC_percent','SOC change (pp)'),
               ('equivalent_fuel_L_100km','Equivalent fuel (L/100 km)')]
        for ax,(key,title) in zip(axes.ravel(),specs):
            vals=[run['metrics'][key] for run in runs]
            ax.bar(np.arange(3),vals,color=COLORS,width=.65)
            ax.set_xticks(np.arange(3),METHODS)
            ax.set_ylabel(title)
            ax.axhline(0,color='#777777',lw=.5)
        label_axes(axes)
        fig.suptitle(f'{cycle} | single-seed diagnostic comparison',fontsize=9)
        fig.tight_layout(rect=(0,0,1,.95))
        save(fig,out/f'{cycle}_metrics')

        # Trace columns are the actual physical observation bus; torque-speed
        # power conversion is kW = rpm * Nm / 9549 (no additional /1000).
        run=runs[2]; t,q=run['time'],run['trace']
        fig,axes=plt.subplots(3,2,figsize=(7.2,5.6),sharex=True)
        specs=[(q[4],'Engine speed (rpm)'),(q[35],'Engine torque (N m)'),
               (q[31],'Engine power (kW)'),(q[34],'Battery power (kW)'),
               (q[22],'Battery voltage (V)'),(q[23],'Battery current (A)')]
        for ax,(y,title) in zip(axes.ravel(),specs):
            ax.plot(t,y,color=COLORS[2],lw=.8); ax.set_ylabel(title)
        for ax in axes[-1]: ax.set_xlabel('Time (s)')
        label_axes(axes)
        fig.suptitle(f'{cycle} | Transformer powertrain response',fontsize=9)
        fig.tight_layout(rect=(0,0,1,.95))
        save(fig,out/f'{cycle}_transformer_components')

    metrics=pd.DataFrame(rows)
    metrics.to_csv(out/'comparison_metrics.csv',index=False)
    # Cross-cycle summary: keep scales separate so SOC and tracking are not
    # visually dominated by fuel magnitude.
    fig, axes=plt.subplots(2,2,figsize=(7.2,4.8))
    for ax,(key,title) in zip(axes.ravel(),[
            ('RMSE_kmh','Speed RMSE (km/h)'),('fuel_L','Fuel (L)'),
            ('delta_SOC_percent','SOC change (pp)'),
            ('equivalent_fuel_L_100km','Equivalent fuel (L/100 km)')]):
        x=np.arange(len(CYCLES)); width=.24
        for j,(method,color) in enumerate(zip(METHODS,COLORS)):
            vals=[metrics.loc[(metrics.cycle==c)&(metrics.controller==method),key].iloc[0] for c in CYCLES]
            ax.bar(x+(j-1)*width,vals,width,color=color,label=method)
        ax.set_xticks(x,CYCLES.keys()); ax.set_ylabel(title); ax.axhline(0,color='#777',lw=.5)
        ax.grid(axis='y',color='#D8D8D8',lw=.4,alpha=.6)
    axes[0,0].legend(fontsize=6,ncols=3,loc='upper left')
    label_axes(axes)
    fig.suptitle('All cycles | three-controller diagnostic summary',fontsize=9)
    fig.tight_layout(rect=(0,0,1,.95))
    save(fig,out/'all_cycles_metrics')
    (out/'data_manifest.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    lines=['# 三控制器绘图与分析','',
           '全部曲线来自当前分支同一批次的完整闭环仿真，seed=1。恢复的是历史权重，没有重新训练。',
           'LSTM 与 Transformer 训练数据来源不同，执行栈也不同；本图用于候选控制器诊断，不能据此断言网络架构优劣。','',
           '| 工况 | 控制器 | RMSE km/h | 油耗 L | SOC变化 pp | 等效油耗 L/100km |',
           '|---|---|---:|---:|---:|---:|']
    for row in rows:
        lines.append(f"| {row['cycle']} | {row['controller']} | {row['RMSE_kmh']:.3f} | {row['fuel_L']:.3f} | {row['delta_SOC_percent']:.3f} | {row['equivalent_fuel_L_100km']:.2f} |")
    lines+=['','## 解读','',
            '原始油耗下降必须结合 SOC变化、实际距离及速度误差判断。低油耗伴随明显放电或距离不足不构成节油优势。等效油耗使用当前分支的SOC自适应因子，按实际完成距离归一化。',
            '高速段及阶跃参考可能超出车辆能力，跟踪误差不能全部归因于EMS。',
            'comparison_metrics.csv 同时包含命令约束、物理超限和运算时间；仿真完成并不代表通过控制器验收。单seed没有置信区间或显著性检验。','',
            '## 数据与出图检查','',
            '9条轨迹全部保留；无降采样、无择优挑选。预测输出按训练Ts对齐物理时间，而不是压缩20步到10步。SVG保留文本节点；同时导出PDF、PNG及600dpi TIFF。原始MAT数据及逐点CSV保留用于复核。']
    (out/'analysis.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    for svg in out.glob('*.svg'):
        tree=ET.parse(svg)
        assert tree.findall('.//{http://www.w3.org/2000/svg}text'),svg
    print(metrics[['cycle','controller','RMSE_kmh','fuel_L','delta_SOC_percent']].to_string(index=False))


if __name__=='__main__': main()
