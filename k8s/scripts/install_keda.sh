#!/bin/bash
# Install KEDA for event-driven autoscaling
# https://keda.sh/docs/2.14/deploy/

set -e

helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  --namespace kube-system \
  --set-string nodeSelector.internal=true \
  --set-string nodeSelector.compute=cpu \
  --set-string nodeSelector.processor=amd64 \
  --set-string nodeSelector.workload=general-purpose \
  --wait

echo "KEDA installed. Verify with:"
echo "  kubectl get pods -n kube-system -l app.kubernetes.io/name=keda-operator"
echo "  kubectl get crd | grep keda"
