
locals {
  name = "eks-ai-ape1"

  observability_namespace       = "observability"
  observability_logging_sa      = "observability-logging-sa"
  observability_logs_bucket_arn = "arn:aws:s3:::ai-platform-logs-169446447120-ap-east-1-an"

  ai_platform_namespace       = "ai-platform"
  aip_litellm_sa              = "aip-litellm"
  aip_litellm_logs_bucket_arn = "arn:aws:s3:::ai-platform-logs-169446447120-ap-east-1-an"
}

module "aws_eks_ai" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15.1"

  name               = local.name
  kubernetes_version = "1.33"
  tags               = var.tags
  enable_irsa        = false

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
    },
    aws-ebs-csi-driver = {
      most_recent = true
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

      min_size     = 1
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

module "aws_eks_ai_observability_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                 = "ai-platform-observability-role"
  create               = true
  attach_custom_policy = true


  policy_statements = [
    {
      sid = "S3ReadOnly"
      actions = [
        "s3:ListAccessPointsForObjectLambda",
        "s3:GetAccessPoint",
        "s3:PutAccountPublicAccessBlock",
        "s3:ListAccessPoints",
        "s3:CreateStorageLensGroup",
        "s3:ListJobs",
        "s3:PutStorageLensConfiguration",
        "s3:ListMultiRegionAccessPoints",
        "s3:ListStorageLensGroups",
        "s3:ListStorageLensConfigurations",
        "s3:GetAccountPublicAccessBlock",
        "s3:ListAllMyBuckets",
        "s3:ListAccessGrantsInstances",
        "s3:PutAccessPointPublicAccessBlock",
        "s3:CreateJob"
      ]
      resources = ["*"]
    },
    {
      sid     = "S3AllOnBucket"
      actions = ["s3:*"]
      resources = [
        local.observability_logs_bucket_arn,
        "${local.observability_logs_bucket_arn}/*"
      ]
    }
  ]

  associations = {
    this = {
      cluster_name    = local.name
      namespace       = local.observability_namespace
      service_account = local.observability_logging_sa
    }
  }
}


module "aws_eks_ai_litellm_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                 = "eks-ai-ape1-aip-litellm-role"
  create               = true
  attach_custom_policy = true


  policy_statements = [
    {
      sid = "S3ReadOnly"
      actions = [
        "s3:ListAccessPointsForObjectLambda",
        "s3:GetAccessPoint",
        "s3:PutAccountPublicAccessBlock",
        "s3:ListAccessPoints",
        "s3:CreateStorageLensGroup",
        "s3:ListJobs",
        "s3:PutStorageLensConfiguration",
        "s3:ListMultiRegionAccessPoints",
        "s3:ListStorageLensGroups",
        "s3:ListStorageLensConfigurations",
        "s3:GetAccountPublicAccessBlock",
        "s3:ListAllMyBuckets",
        "s3:ListAccessGrantsInstances",
        "s3:PutAccessPointPublicAccessBlock",
        "s3:CreateJob"
      ]
      resources = ["*"]
    },
    {
      sid     = "S3AllOnBucket"
      actions = ["s3:*"]
      resources = [
        local.observability_logs_bucket_arn,
        "${local.observability_logs_bucket_arn}/*"
      ]
    }
  ]

  associations = {
    this = {
      cluster_name    = local.name
      namespace       = local.ai_platform_namespace
      service_account = local.aip_litellm_sa
    }
  }
}

module "aws_ebs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                      = "${local.name}-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = local.name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
}
