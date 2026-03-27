
EKS_CLUSTER_NAME="eks-ai-ape1"
KARPENTER_VERSION="1.9.0"
ACCOUNT_ID="169446447120"
AWS_DEFAULT_REGION="ap-east-1"
KARPENTER_CONTROLL_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${EKS_CLUSTER_NAME}-karpenter-controller"

helm upgrade \
    --install karpenter oci://${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ecr-public/karpenter/karpenter \
    --version "${KARPENTER_VERSION}" \
    --namespace "kube-system" \
    --create-namespace \
    --set "settings.clusterName=${EKS_CLUSTER_NAME}" \
    --set "settings.interruptionQueue=${EKS_CLUSTER_NAME}" \
    --set controller.resources.requests.cpu=1 \
    --set controller.resources.requests.memory=1Gi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --set controller.image.repository=${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ecr-public/karpenter/controller