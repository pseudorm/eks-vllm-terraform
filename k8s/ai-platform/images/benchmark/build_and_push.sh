#!/bin/bash
# Build and push the two benchmark images to ECR.
# Usage: ./build_and_push.sh [account-id] [region]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_ID="${1:-386865647718}"
REGION="${2:-us-east-1}"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for image in llm-benchmark-runner:runner llm-benchmark-terminal-bench:terminal-bench; do
  repo="${image%%:*}"
  dir="${image##*:}"
  aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1 \
    || aws ecr create-repository --repository-name "$repo" --region "$REGION" >/dev/null

  echo "Building ${REGISTRY}/${repo}:latest from ${dir}/ ..."
  docker build -t "${REGISTRY}/${repo}:latest" "${SCRIPT_DIR}/${dir}"
  docker push "${REGISTRY}/${repo}:latest"
done

echo "Done. Update runnerImage.repository / terminalBenchImage.repository in values.yaml if REGISTRY differs from the default."
