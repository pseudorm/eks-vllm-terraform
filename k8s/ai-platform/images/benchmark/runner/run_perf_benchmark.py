#!/usr/bin/env python3
"""Sweep concurrency levels through guidellm against one or more OpenAI-compatible targets.

Reads /etc/benchmark/config.yaml (see templates/configmap.yaml), runs one `guidellm run`
per (target, concurrency) pair, then hands off to aggregate_perf_results.py to combine
everything into a single concurrency-vs-metric report.
"""
import argparse
import os
import pathlib
import subprocess
import sys

import yaml


def run_guidellm(target_name: str, base_url: str, api_key: str, model: str, concurrency: int, perf_cfg: dict, out_dir: pathlib.Path) -> bool:
    out_dir.mkdir(parents=True, exist_ok=True)

    backend = f"kind=openai_http,target={base_url},model={model}"
    if api_key:
        backend += f",api_key={api_key}"

    cmd = [
        "guidellm", "run",
        "--backend", backend,
        "--profile", f"kind=concurrent,streams={concurrency}",
        "--data", f"kind=synthetic_text,prompt_tokens={perf_cfg['prompt_tokens']},output_tokens={perf_cfg['output_tokens']}",
        "--constraint", f"kind=max_duration,seconds={perf_cfg['max_seconds_per_level']}",
        "--constraint", f"kind=max_requests,count={perf_cfg['max_requests_per_level']}",
    ]

    env = dict(os.environ)
    if api_key:
        # Belt-and-suspenders: guidellm's openai_http backend takes api_key= directly above,
        # but also honor the standard OPENAI_API_KEY env var in case that's what it reads.
        env["OPENAI_API_KEY"] = api_key

    print(f"[perf] {target_name} concurrency={concurrency}: {' '.join(cmd)}", flush=True)
    result = subprocess.run(cmd, cwd=out_dir, env=env)
    if result.returncode != 0:
        print(
            f"[perf] WARNING: guidellm exited {result.returncode} for {target_name} "
            f"concurrency={concurrency}. Run `guidellm run --help` in this image to confirm "
            f"current flag names if this keeps failing.",
            file=sys.stderr,
        )
    return result.returncode == 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()

    with open(args.config) as f:
        cfg = yaml.safe_load(f)

    perf_cfg = cfg["perf"]
    model = cfg["served_model_name"]
    results_root = pathlib.Path(cfg["results_root"]) / "perf" / args.run_id

    all_ok = True
    for target_name, target in cfg["targets"].items():
        api_key = os.environ.get(target["api_key_env"], "")
        for concurrency in perf_cfg["concurrency_levels"]:
            out_dir = results_root / target_name / f"concurrency_{concurrency}"
            ok = run_guidellm(target_name, target["base_url"], api_key, model, concurrency, perf_cfg, out_dir)
            all_ok = all_ok and ok

    print(f"[perf] sweep complete, aggregating -> {results_root}", flush=True)
    subprocess.run([sys.executable, "/app/aggregate_perf_results.py", "--run-dir", str(results_root)], check=False)
    print(f"[perf] results at /benchmarks/perf/{args.run_id}/ (via the perf-viewer ingress)", flush=True)

    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
