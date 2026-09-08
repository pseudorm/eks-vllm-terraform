#!/usr/bin/env python3
"""Run Terminal-Bench against the target model via the dind sidecar in the same pod.

terminal-bench routes models through litellm; "openai/<model>" plus OPENAI_API_BASE /
OPENAI_API_KEY (set on the Job, see templates/jobs/terminal-bench-job.yaml) is litellm's
convention for pointing that provider string at a custom OpenAI-compatible base URL.
"""
import argparse
import pathlib
import subprocess
import sys
import time

import yaml


def wait_for_docker(timeout_seconds: int = 120) -> bool:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        result = subprocess.run(["docker", "info"], capture_output=True)
        if result.returncode == 0:
            return True
        time.sleep(3)
    return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()

    with open(args.config) as f:
        cfg = yaml.safe_load(f)

    tb_cfg = cfg["terminal_bench"]
    model = cfg["served_model_name"]
    out_dir = pathlib.Path(cfg["results_root"]) / "terminal-bench" / args.run_id
    out_dir.mkdir(parents=True, exist_ok=True)

    print("[terminal-bench] waiting for dind sidecar...", flush=True)
    if not wait_for_docker():
        print("[terminal-bench] docker daemon in the dind sidecar never became ready", file=sys.stderr)
        sys.exit(1)

    cmd = [
        "tb", "run",
        "--agent", tb_cfg["agent"],
        "--model", f"openai/{model}",
        "--dataset-name", tb_cfg["dataset_name"],
        "--dataset-version", tb_cfg["dataset_version"],
        "--n-concurrent", str(tb_cfg["n_concurrent"]),
    ]
    # tb's exact output-directory flag wasn't confirmable at authoring time, so we run with
    # cwd=out_dir instead - whatever relative output dir it creates by default lands there.
    print(f"[terminal-bench] {' '.join(cmd)} (cwd={out_dir})", flush=True)
    print(
        "[terminal-bench] NOTE: verify --dataset-name/--dataset-version against "
        "`tb datasets list` / `tb run --help` in this image before trusting results - "
        "terminal-bench v2's exact dataset identifiers weren't confirmable at authoring time.",
        flush=True,
    )
    result = subprocess.run(cmd, cwd=out_dir)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
