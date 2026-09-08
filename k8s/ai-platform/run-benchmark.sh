#!/bin/bash
# Launch one ad-hoc benchmark Job against the deployed platform and tail its logs.
#
# Renders ONLY the matching Job from templates/benchmark/jobs/ and kubectl-applies it.
# The chart's own resources (ConfigMap, Secret, results PVC, viewers, ingress) come from
# ./install.sh -- this script never touches them.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-ai-platform}"
RELEASE_NAME="${RELEASE_NAME:-aip}"

usage() {
  cat <<EOF
Usage: $0 <perf|eval|terminal-bench> [--concurrency 1,2,4,8,16] [--set key=value ...]

  perf            guidellm concurrency sweep (TTFT, throughput, latency, success rate)
  eval            inspect_ai eval-set over benchmark.evals.tasks (HLE, coding, ...)
  terminal-bench  Terminal-Bench v2 via the privileged dind sidecar Job

Env: NAMESPACE (default ai-platform), RELEASE_NAME (default aip)

Examples:
  $0 perf --concurrency 1,2,4,8,16,32,64
  $0 eval --set benchmark.evals.tasks='{hle,humaneval}'
  $0 terminal-bench --set benchmark.terminalBench.nConcurrent=8
EOF
  exit 1
}

[ $# -ge 1 ] || usage
MODE="$1"; shift

case "$MODE" in
  perf)           TEMPLATE="templates/benchmark/jobs/perf-benchmark-job.yaml";  JOB_SUFFIX="perf" ;;
  eval)           TEMPLATE="templates/benchmark/jobs/capability-eval-job.yaml"; JOB_SUFFIX="eval" ;;
  terminal-bench) TEMPLATE="templates/benchmark/jobs/terminal-bench-job.yaml";  JOB_SUFFIX="tbench" ;;
  *) usage ;;
esac

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
SET_ARGS=("--set" "benchmark.run=${MODE}" "--set" "benchmark.runId=${RUN_ID}")

while [ $# -gt 0 ]; do
  case "$1" in
    --concurrency)
      [ $# -ge 2 ] || { echo "--concurrency needs a value" >&2; usage; }
      # "1,2,4" -> "{1,2,4}", helm's list literal syntax (avoids needing jq)
      SET_ARGS+=("--set" "benchmark.perf.concurrencyLevels={$2}")
      shift 2
      ;;
    --set)
      [ $# -ge 2 ] || { echo "--set needs a value" >&2; usage; }
      SET_ARGS+=("--set" "$2")
      shift 2
      ;;
    *) echo "Unknown flag: $1" >&2; usage ;;
  esac
done

echo "Rendering ${MODE} job (run-id=${RUN_ID})..."
helm template "$RELEASE_NAME" "$SCRIPT_DIR" \
  --namespace "$NAMESPACE" \
  -f "$SCRIPT_DIR/values.yaml" \
  -f "$SCRIPT_DIR/values-secrets.yaml" \
  -f "$SCRIPT_DIR/values-litellm.yaml" \
  -f "$SCRIPT_DIR/values-bifrost.yaml" \
  -f "$SCRIPT_DIR/values-comfyui.yaml" \
  -f "$SCRIPT_DIR/values-vllm.yaml" \
  -f "$SCRIPT_DIR/values-ollama.yaml" \
  -f "$SCRIPT_DIR/values-benchmark.yaml" \
  "${SET_ARGS[@]}" \
  --show-only "$TEMPLATE" \
  | kubectl apply -n "$NAMESPACE" -f -

JOB_NAME="${RELEASE_NAME}-benchmark-${JOB_SUFFIX}-${RUN_ID}"
echo "Applied job/${JOB_NAME}. Waiting for its pod..."
kubectl wait -n "$NAMESPACE" --for=condition=Ready pod -l "job-name=${JOB_NAME}" --timeout=300s || true
kubectl logs -n "$NAMESPACE" -f "job/${JOB_NAME}" --all-containers=true
