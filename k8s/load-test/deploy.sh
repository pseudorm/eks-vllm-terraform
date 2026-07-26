#!/bin/bash
# Deploy Locust to EKS cluster
set -e

NAMESPACE="load-test"
LOCUSTFILE="${LOCUSTFILE:-locustfile_claude_code.py}"
LITELLM_API_KEY="${LITELLM_API_KEY:-sk-1234}"

# Resolve script paths relative to this file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "==> Creating namespace"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating secret with API key"
kubectl create secret generic locust-secrets \
  --from-literal=litellm-api-key="$LITELLM_API_KEY" \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating ConfigMap from $LOCUSTFILE"
kubectl create configmap locust-script \
  --from-file=locustfile.py="$LOCUSTFILE" \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying master and workers"
kubectl apply -f "$SCRIPT_DIR/locust-master.yaml"
kubectl apply -f "$SCRIPT_DIR/locust-worker.yaml"

echo "==> Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=locust,role=master -n $NAMESPACE --timeout=120s
kubectl wait --for=condition=ready pod -l app=locust,role=worker -n $NAMESPACE --timeout=120s

echo ""
echo "==> Locust is running!"
echo ""
echo "Access the UI:"
echo "  kubectl port-forward -n $NAMESPACE svc/locust-master 8089:8089"
echo "  Open: http://localhost:8089"
echo ""
echo "Scale workers (more = more load):"
echo "  kubectl scale deployment/locust-worker -n $NAMESPACE --replicas=10"
echo ""
echo "Update the locustfile:"
echo "  ./k8s/locust/deploy.sh"
echo "  kubectl rollout restart deployment/locust-master -n $NAMESPACE"
echo "  kubectl rollout restart deployment/locust-worker -n $NAMESPACE"
echo ""
echo "Tear down:"
echo "  kubectl delete namespace $NAMESPACE"
