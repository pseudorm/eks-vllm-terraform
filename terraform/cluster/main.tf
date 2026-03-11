
locals {
  name = "eks-ai-ape1"
}

module "aws_eks_ai" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15.1"

  name               = local.name
  kubernetes_version = "1.33"
  tags               = var.tags

  endpoint_public_access                   = false
  enable_cluster_creator_admin_permissions = true

  # Network related config
  vpc_id                        = var.vpc_id
  control_plane_subnet_ids      = var.cluster_subnet_ids
  subnet_ids                    = var.node_subnet_ids
  create_security_group         = false
  create_node_security_group    = false
  security_group_id             = var.cluster_security_group_id
  node_security_group_id        = var.node_security_group_id
  additional_security_group_ids = []

  addons = {
    kube-proxy = {
      most_recent    = true
      before_compute = true
    },
    coredns = {
      most_recent    = true
      before_compute = true
    },
    eks-pod-identity-agent = {
      before_compute = true
    },
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }


  # Karpenter controller 
  eks_managed_node_groups = {
    karpenter = {
      ami_type               = "BOTTLEROCKET_ARM_64"
      capacity_type          = "ON_DEMAND"
      create_iam_role        = true
      create_launch_template = true
      instance_types         = ["t4g.medium"]
      subnet_ids             = var.node_subnet_ids

      min_size     = 2
      max_size     = 10
      desired_size = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge({ "karpenter.sh/discovery" : local.name }, var.tags)
}

# Karpenter module
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.15.1"


  cluster_name                    = module.aws_eks_ai.cluster_name
  create_iam_role                 = true
  create_node_iam_role            = false
  create_pod_identity_association = true
  enable_spot_termination         = true
  iam_role_name                   = "${local.name}-karpenter-controller"
  iam_role_use_name_prefix        = false
  node_iam_role_arn               = module.aws_eks_ai.eks_managed_node_groups["karpenter"].iam_role_arn
  service_account                 = "karpenter"

  # Since the node group role will already have an access entry
  create_access_entry = false

  tags = var.tags
}
