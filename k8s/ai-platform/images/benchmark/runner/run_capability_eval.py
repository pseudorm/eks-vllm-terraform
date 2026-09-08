#!/usr/bin/env python3
"""Run the configured inspect_evals task suite (HLE, coding benchmarks, ...) against LiteLLM.

Uses inspect_ai's generic openai-api provider so no custom model client is needed:
model = openai-api/litellm/<served-model-name>, pointed at LiteLLM via the LITELLM_BASE_URL /
LITELLM_API_KEY env vars set on the Job (see templates/jobs/capability-eval-job.yaml).
"""
import argparse
import pathlib
import subprocess
import sys

import yaml


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()

    with open(args.config) as f:
        cfg = yaml.safe_load(f)

    model = cfg["served_model_name"]
    evals_cfg = cfg["evals"]
    log_dir = pathlib.Path(cfg["results_root"]) / "evals" / args.run_id
    log_dir.mkdir(parents=True, exist_ok=True)

    tasks = [f"inspect_evals/{t}" for t in evals_cfg["tasks"]]

    cmd = [
        "inspect", "eval-set", *tasks,
        "--model", f"openai-api/litellm/{model}",
        "--max-connections", str(evals_cfg["max_connections"]),
        "--limit", str(evals_cfg["log_limit"]),
        "--log-dir", str(log_dir),
    ]
    print(f"[eval] {' '.join(cmd)}", flush=True)
    result = subprocess.run(cmd)
    print(f"[eval] results at logs under /results/evals/{args.run_id}/ - view with `inspect view` "
          f"(see the eval-viewer Deployment / README for a kubectl port-forward one-liner)", flush=True)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
