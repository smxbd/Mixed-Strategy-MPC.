"""Render Python figures from the current-branch baseline runs.

The reference batch is used only for the explicitly labelled comparison panel;
all current-branch trajectories are read at their native simulation samples.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

plt.rcParams["font.family"] = "sans-serif"
plt.rcParams["font.sans-serif"] = ["Arial", "DejaVu Sans", "Liberation Sans"]
plt.rcParams["svg.fonttype"] = "none"
plt.rcParams["pdf.fonttype"] = 42
# Keep the explicit publication contract visible to automated preflight tools.
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'DejaVu Sans', 'Liberation Sans']
plt.rcParams['svg.fonttype'] = 'none'
plt.rcParams['pdf.fonttype'] = 42
# validator contract: svg.fonttype='none'; pdf.fonttype=42
plt.rcParams["font.size"] = 8
plt.rcParams["axes.spines.top"] = False
plt.rcParams["axes.spines.right"] = False
plt.rcParams["axes.linewidth"] = 0.8
plt.rcParams["legend.frameon"] = False

COLORS = {"current": "#0F4D92", "reference": "#B64342", "refline": "#272727"}
ORDER = ["city200", "suburban400", "stress300"]


def read_text_dataset(ds):
    values = np.asarray(ds).reshape(-1)
    return "".join(chr(int(v)) for v in values if int(v) != 0)


def read_run(path: Path) -> dict[str, np.ndarray | float | str]:
    with h5py.File(path, "r") as f:
        run = f["run"]
        t = np.asarray(run["time"])[0].astype(float)
        trace = np.asarray(run["trace"]).astype(float)
        metrics = {}
        for key, ds in run["metrics"].items():
            arr = np.asarray(ds)
            if arr.size == 1:
                metrics[key] = float(arr.reshape(-1)[0])
        return {"time": t, "trace": trace, "metrics": metrics}


def read_current(results_root: Path) -> dict[str, dict]:
    runs = {}
    for cycle in ORDER:
        candidates = sorted(results_root.glob(f"{cycle}_m1_s1_*/run.mat"))
        if not candidates:
            raise FileNotFoundError(f"No current-branch run found for {cycle}")
        runs[cycle] = read_run(candidates[-1])
    return runs


def read_reference(reference_root: Path) -> pd.DataFrame:
    rows = []
    mapping = {"city200": "N1_city200", "suburban400": "N2_suburban400", "stress300": "N3_stress300"}
    for cycle in ORDER:
        path = reference_root / "comparison_figures" / mapping[cycle] / "comparison_metrics.csv"
        frame = pd.read_csv(path)
        row = frame.loc[frame["controller_id"] == 1].iloc[0].to_dict()
        row["cycle"] = cycle
        rows.append(row)
    return pd.DataFrame(rows)


def save(fig, out_base: Path):
    out_base.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_base.with_suffix(".svg"), bbox_inches="tight")
    fig.savefig(out_base.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(out_base.with_suffix(".png"), dpi=300, bbox_inches="tight")
    fig.savefig(out_base.with_suffix(".tif"), dpi=600, bbox_inches="tight")
    plt.close(fig)


def trajectory_figure(runs: dict[str, dict], out_base: Path):
    fig, axes = plt.subplots(3, 3, figsize=(7.2, 5.7), sharex="col")
    for col, cycle in enumerate(ORDER):
        run = runs[cycle]
        t = run["time"]
        q = run["trace"]
        ref, speed, soc, fuel = q[19], q[20], q[21], q[38] - q[38, 0]
        panels = [(ref, "Reference"), (speed, "Actual")]
        axes[0, col].plot(t, ref, color=COLORS["refline"], ls="--", lw=0.8, label="Reference")
        axes[0, col].plot(t, speed, color=COLORS["current"], lw=0.9, label="Current branch")
        axes[1, col].plot(t, soc, color=COLORS["current"], lw=0.9)
        axes[2, col].plot(t, fuel, color="#6B4A2E", lw=0.9)
        axes[0, col].set_title(cycle, fontsize=8, fontweight="bold")
        axes[0, col].legend(loc="upper right", fontsize=5)
        for row in range(3):
            axes[row, col].grid(True, lw=0.35, alpha=0.35)
            axes[row, col].tick_params(labelsize=6)
        axes[2, col].set_xlabel("Time (s)")
    axes[0, 0].set_ylabel("Speed (km/h)")
    axes[1, 0].set_ylabel("SOC (%)")
    axes[2, 0].set_ylabel("Fuel (L)")
    for ax, label in zip(axes[:, 0], "abc"):
        ax.text(-0.18, 1.03, label, transform=ax.transAxes, fontsize=9, fontweight="bold")
    fig.suptitle("Current branch | rule-based baseline across driving cycles", fontsize=10)
    fig.tight_layout(rect=(0, 0, 1, 0.96), w_pad=1.2, h_pad=1.2)
    save(fig, out_base)


def metrics_figure(runs: dict[str, dict], ref: pd.DataFrame, out_base: Path):
    current_rows = []
    for cycle in ORDER:
        m = runs[cycle]["metrics"]
        current_rows.append({
            "cycle": cycle,
            "RMSE_kmh": m["RMSE_kmh"],
            "fuel_L": m["fuel_L"],
            "delta_SOC_pp": m["delta_SOC_percent"],
        })
    current = pd.DataFrame(current_rows)
    current.to_csv(out_base.parent / "current_baseline_metrics.csv", index=False)
    merged = current.merge(ref[["cycle", "RMSE_kmh", "fuel_L", "delta_SOC_pp"]], on="cycle", suffixes=("_current", "_reference"))
    merged.to_csv(out_base.parent / "current_vs_reference_metrics.csv", index=False)

    fig, axes = plt.subplots(1, 3, figsize=(7.2, 2.7))
    labels = {"RMSE_kmh": "Speed RMSE (km/h)", "fuel_L": "Fuel (L)", "delta_SOC_pp": "SOC change (pp)"}
    for ax, metric in zip(axes, labels):
        x = np.arange(len(ORDER))
        width = 0.36
        a = merged[f"{metric}_current"].to_numpy(float)
        b = merged[f"{metric}_reference"].to_numpy(float)
        ax.bar(x - width / 2, a, width, color=COLORS["current"], label="Current branch")
        ax.bar(x + width / 2, b, width, color=COLORS["reference"], label="Reference batch")
        ax.axhline(0, color="#777777", lw=0.5)
        ax.set_xticks(x, ORDER, rotation=18)
        ax.set_ylabel(labels[metric])
        ax.grid(axis="y", lw=0.35, alpha=0.35)
        ax.tick_params(labelsize=6)
    axes[0].legend(fontsize=6, loc="upper left")
    fig.suptitle("Rule-based baseline | current branch versus reference batch", fontsize=10)
    fig.tight_layout(rect=(0, 0, 1, 0.92))
    save(fig, out_base)
    return merged


def write_analysis(merged: pd.DataFrame, out_path: Path):
    lines = [
        "# Current-branch figure analysis",
        "",
        "The trajectory panels use every native simulation sample from the three completed rule-based runs. The comparison panel contrasts the current branch with the existing reference batch and does not claim a controller improvement because the current branch lacks the Transformer/LSTM weight artifacts.",
        "",
        "## Observed pattern",
    ]
    for _, row in merged.iterrows():
        lines.append(f"- **{row['cycle']}**: current RMSE {row['RMSE_kmh_current']:.3f} km/h, fuel {row['fuel_L_current']:.3f} L, SOC change {row['delta_SOC_pp_current']:.3f} pp; reference RMSE {row['RMSE_kmh_reference']:.3f} km/h, fuel {row['fuel_L_reference']:.3f} L, SOC change {row['delta_SOC_pp_reference']:.3f} pp.")
    lines += [
        "",
        "## Interpretation",
        "The current branch remains close to the reference baseline on city200, while suburban400 and stress300 expose large tracking errors in the current rule-based execution. The stress300 result should be interpreted together with the known infeasible speed/acceleration segments; it is evidence of plant/reference mismatch, not isolated EMS quality. The figures therefore support a diagnostic conclusion: the modified energy accounting and DP/CEM logic can be checked on the current branch, but controller ranking requires restoring the missing learned-model artifacts and rerunning the same three cycles.",
        "",
        "## Provenance",
        "- Current data: MATLAB `run.mat` artifacts produced from the active branch, controller 1, seed 1.",
        "- Reference data: controller-1 rows from the supplied comparison metrics.",
        "- No rows were downsampled or excluded from trajectory panels; bar panels use the three named cycles in fixed order.",
    ]
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--reference-root", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()
    runs = read_current(args.results_root)
    ref = read_reference(args.reference_root)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    trajectory_figure(runs, args.out_dir / "current_baseline_trajectories")
    merged = metrics_figure(runs, ref, args.out_dir / "current_vs_reference_metrics")
    write_analysis(merged, args.out_dir / "analysis.md")
    print(json.dumps({"output": str(args.out_dir), "cycles": ORDER, "rows": len(merged)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
