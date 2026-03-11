EKS_CLUSTER_NAME="eks-ai-ape1"
ACCOUNT_ID="169446447120"
AWS_DEFAULT_REGION="ap-east-1"

# Get VPC ID from EKS cluster
echo "Retrieving VPC ID from EKS cluster..."
VPC_ID=$(aws eks describe-cluster \
  --name ${EKS_CLUSTER_NAME} \
  --region ${AWS_DEFAULT_REGION} \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

echo "VPC ID: ${VPC_ID}"

# Install AWS Load Balancer Controller
helm upgrade \
    --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=${EKS_CLUSTER_NAME} \
    --set vpcId=${VPC_ID} \
    --set region=${AWS_DEFAULT_REGION} \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set image.repository=${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ecr-public/eks/aws-load-balancer-controller \
    --version 3.1.0 

echo "AWS Load Balancer Controller installed successfully!"
