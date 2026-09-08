#!/usr/bin/env python3
"""Combine per-concurrency guidellm benchmarks.csv files into one comparison report.

guidellm writes benchmarks.{json,csv,html} into the cwd of each `guidellm run` invocation.
run_perf_benchmark.py invokes it once per (target, concurrency) into
<run-dir>/<target>/concurrency_<n>/. This script walks that tree, concatenates the CSVs,
and plots every metric column that looks like TTFT/ITL/throughput/latency/success/error
against concurrency, one line per target.
"""
import argparse
import pathlib
import sys

import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

METRIC_KEYWORDS = ("ttft", "itl", "tpot", "token", "latency", "throughput", "request", "success", "error")


def load_run(csv_path: pathlib.Path, target: str, concurrency: int) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df["target"] = target
    df["concurrency"] = concurrency
    return df


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True, help="e.g. /results/perf/<run-id>")
    args = parser.parse_args()
    run_dir = pathlib.Path(args.run_dir)

    frames = []
    for csv_path in sorted(run_dir.glob("*/concurrency_*/benchmarks.csv")):
        target = csv_path.parent.parent.name
        try:
            concurrency = int(csv_path.parent.name.rsplit("_", 1)[-1])
        except ValueError:
            continue
        try:
            frames.append(load_run(csv_path, target, concurrency))
        except Exception as e:
            print(f"[aggregate] skipping {csv_path}: {e}", file=sys.stderr)

    if not frames:
        print(f"[aggregate] no benchmarks.csv files found under {run_dir} - nothing to aggregate", file=sys.stderr)
        sys.exit(1)

    combined = pd.concat(frames, ignore_index=True)
    combined.to_csv(run_dir / "combined.csv", index=False)

    metric_cols = [c for c in combined.columns if any(k in c.lower() for k in METRIC_KEYWORDS)]
    numeric_cols = [c for c in metric_cols if pd.api.types.is_numeric_dtype(combined[c])]

    if not numeric_cols:
        print(
            f"[aggregate] wrote {run_dir / 'combined.csv'} but found no TTFT/latency/throughput-like "
            f"numeric columns to plot. Inspect combined.csv's headers - guidellm's exact column "
            f"names may differ from METRIC_KEYWORDS in this script.",
            file=sys.stderr,
        )
        sys.exit(0)

    fig = make_subplots(rows=len(numeric_cols), cols=1, subplot_titles=numeric_cols, shared_xaxes=True)
    for i, col in enumerate(numeric_cols, start=1):
        for target, group in combined.groupby("target"):
            group = group.sort_values("concurrency")
            fig.add_trace(
                go.Scatter(x=group["concurrency"], y=group[col], mode="lines+markers", name=f"{target}: {col}"),
                row=i, col=1,
            )
        fig.update_yaxes(title_text=col, row=i, col=1)
    fig.update_xaxes(title_text="Concurrency", row=len(numeric_cols), col=1)
    fig.update_layout(height=320 * len(numeric_cols), title=f"Perf sweep: {run_dir.name}", showlegend=True)
    fig.write_html(str(run_dir / "summary.html"), include_plotlyjs="cdn")
    print(f"[aggregate] wrote {run_dir / 'combined.csv'} and {run_dir / 'summary.html'}")


if __name__ == "__main__":
    main()
