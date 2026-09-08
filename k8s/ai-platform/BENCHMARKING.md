# Benchmarking the platform

Part of the `ai-platform` chart. Measures the deployed vLLM/LiteLLM along two axes:

- **Performance vs. concurrency** — TTFT, inter-token latency, output tokens/sec, server
  throughput, end-to-end latency, achieved request rate, and success rate, swept across a list of
  concurrency levels. Uses [guidellm](https://github.com/vllm-project/guidellm), the vLLM team's
  own load-testing tool, rather than a custom load generator.
- **Capability** — Humanity's Last Exam, coding benchmarks (HumanEval, MBPP, BigCodeBench) via
  [inspect_ai](https://inspect.aisi.org.uk/) + `inspect_evals`, and agentic terminal use via
  [terminal-bench](https://www.tbench.ai/).

Everything lives in the platform chart so the perf reports share the platform ALB, and so the
benchmark targets are derived from the release (`{{ .Release.Name }}-vllm`,
`-litellm-data`) instead of hardcoded hostnames.

## Files

| Path | What |
|---|---|
| `values-benchmark.yaml` | All benchmark config, under a `benchmark:` key |
| `templates/benchmark/` | ConfigMap, Secret, results PVC, viewers, and the three Jobs |
| `images/benchmark/` | Build contexts for the runner and terminal-bench images |
| `run-benchmark.sh` | Launches one ad-hoc Job and tails its logs |

## One-time setup

1. **Create the S3 results bucket** named in `values-benchmark.yaml`
   (`benchmark.results.s3Bucket.name`), then add its ARN to the `s3-csi-driver` pod identity in
   `terraform/eks-ai-use1-cluster/pod_identities.tf` (`aws_s3_csi_pod_identity` →
   `mountpoint_s3_csi_bucket_arns` / `..._bucket_path_arns`, already wired for this bucket) and
   `terraform apply`. Until this exists the results PVC stays `Pending` and the two viewer pods
   won't start — the rest of the platform is unaffected.
2. **Build and push the images**: `./images/benchmark/build_and_push.sh <account-id> <region>`.
3. **Set `benchmark.target.servedModelName`** in `values-benchmark.yaml` to match
   `vllm.runtimeArgs.model` in `values-vllm.yaml` and the LiteLLM model alias.
4. **Add a LiteLLM virtual key** to `values-secrets.yaml` (gitignored):
   ```yaml
   benchmark:
     litellmApiKey: "sk-..."
   ```
   Prefer a key scoped to the benchmark model over `LITELLM_MASTER_KEY`.
5. `./install.sh` — creates the ConfigMap, Secret, PVC, viewers, and the ingress path. Launches
   no benchmark runs.

## Running

```
./run-benchmark.sh perf --concurrency 1,2,4,8,16,32,64,128
./run-benchmark.sh eval                                  # HLE + HumanEval + MBPP + BigCodeBench
./run-benchmark.sh terminal-bench
```

Each run is a one-off `Job` — these are on-demand comparisons ("before/after a vLLM config
change"), not a continuous pipeline. Results land on the S3-backed PVC whether or not you keep
watching the logs.

The Jobs render **only** when `benchmark.run` is set, which `run-benchmark.sh` does per
invocation. A plain `./install.sh` or `helm upgrade` leaves it empty and starts nothing.

## Viewing results

- **Perf**: `https://<platform-host>/benchmarks/perf/` — directory listing of runs, each with a
  `summary.html` plotting every metric against concurrency, one line per target.
- **Evals**: `inspect view` has no path-prefix support and no real auth, so it is ClusterIP-only:
  ```
  kubectl -n ai-platform port-forward svc/aip-benchmark-eval-viewer 7575:7575
  ```
- **Terminal-Bench**: `results.json` + per-task transcripts under
  `/results/terminal-bench/<run-id>/`; `aws s3 sync` the prefix down to read them.

## Privileged container

The Terminal-Bench Job is the only component needing `privileged: true` — Terminal-Bench gives
the agent a Docker sandbox per task, which needs a real Docker daemon (the `docker:26-dind`
sidecar).

A privileged escape compromises the **node**, not just the namespace, so the control that matters
is node placement, not namespace separation. `benchmark.terminalBench.nodeSelector` therefore
targets `workload: hpc` (`cpu-hpc-amd64-ec2`) — the only workload label no other ai-platform
component requests. For reference, the LiteLLM control plane and Open-WebUI sit on
`general-purpose` and the LiteLLM **data** plane on `compute-optimized`, so neither of those pools
is a safe home for a privileged pod. Re-check before changing it:

```
grep -rh 'workload:' values*.yaml | sort -u
```

That nodepool carries no taint, so this is convention rather than enforcement — add a taint plus
matching toleration if you want it guaranteed. The Job also runs with
`automountServiceAccountToken: false` and no `serviceAccountName`, so it never picks up the
`aip-litellm` pod identity's S3/Bedrock permissions.

If you'd rather not run a privileged pod in this namespace at all, set
`benchmark.terminalBench` aside and skip that mode — `perf` and `eval` need no special
privileges.

## Verify before trusting results

Three CLI details couldn't be confirmed from docs alone at authoring time. Each is a one-time
check, not a per-run one:

- **guidellm backend sub-flags**: `--backend kind=openai_http,target=...,model=...,api_key=...`.
  The `model=` / `api_key=` sub-keys are inferred from guidellm's `key=value` convention, not an
  explicit doc example. If a sweep fails immediately, run `guidellm run --help` in the runner
  image and diff against `images/benchmark/runner/run_perf_benchmark.py`.
- **Terminal-Bench dataset IDs**: `benchmark.terminalBench.datasetName` / `datasetVersion`
  default to `terminal-bench-core` / `2.0.0`, which are guesses. Confirm with
  `tb datasets list` in the terminal-bench image.
- **guidellm CSV columns**: `aggregate_perf_results.py` matches metric columns by keyword
  (`ttft`, `itl`, `token`, `latency`, `throughput`, `request`, `success`, `error`) because the CSV
  schema wasn't inspectable. If a run produces `combined.csv` but no `summary.html`, no column
  matched — check the headers and adjust `METRIC_KEYWORDS`.
