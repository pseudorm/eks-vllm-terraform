helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update
# Install both CRDs and KubeRay operator v1.6.0.
helm install kuberay-operator kuberay/kuberay-operator --version 1.6.0 -n ray
