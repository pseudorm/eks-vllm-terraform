#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-ai-platform}"
RELEASE_NAME="${RELEASE_NAME:-aip}"


echo "Installing/upgrading ${RELEASE_NAME} in namespace ${NAMESPACE}..."
helm upgrade --install "$RELEASE_NAME" "$SCRIPT_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --server-side=false \
  -f "$SCRIPT_DIR/values.yaml" \
  -f "$SCRIPT_DIR/values-secrets.yaml" \
  -f "$SCRIPT_DIR/values-litellm.yaml" \
  -f "$SCRIPT_DIR/values-bifrost.yaml" \
  -f "$SCRIPT_DIR/values-comfyui.yaml" \
  -f "$SCRIPT_DIR/values-vllm.yaml" \
  -f "$SCRIPT_DIR/values-ollama.yaml" \
  -f "$SCRIPT_DIR/values-benchmark.yaml" \
  "$@"

echo "Done. Check status with:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl get ingress -n ${NAMESPACE}"
echo "Run a benchmark with ./run-benchmark.sh perf|eval|terminal-bench (see BENCHMARKING.md)"
