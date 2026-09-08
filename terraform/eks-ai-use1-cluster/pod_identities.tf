

module "aws_eks_albc_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                            = "albc-controller-role"
  create                          = true
  attach_aws_lb_controller_policy = true
  associations = {
    this = {
      cluster_name    = local.name
      namespace       = local.kube_system_namespace
      service_account = local.albc_sa
    }
  }

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

  tags = var.tags
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
        "${local.observability_logs_bucket_arn}/*",
        local.aip_litellm_logs_bucket_arn,
        "${local.aip_litellm_logs_bucket_arn}/*"
      ]
    },
    {
      # PutMetricData has no resource-level permissions, so this must be "*".
      # Scope it by adding a cloudwatch:namespace condition if that matters.
      sid       = "CloudWatchPutDeletionMetrics"
      actions   = ["cloudwatch:PutMetricData"]
      resources = ["*"]
    },
    {
      sid = "BedrockAllowCallAllModels"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ApplyGuardrail",
        "bedrock-mantle:*"
      ],
      resources = ["*"]
    }
  ]

  associations = {
    ai_platform_sa = {
      cluster_name    = local.name
      namespace       = local.ai_platform_namespace
      service_account = local.aip_litellm_sa
    },
    s3_gen_job_sa = {
      cluster_name    = local.name
      namespace       = "s3"
      service_account = "s3-generator-sa"

    }
  }

  tags = var.tags
}

module "aws_s3_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                            = "${local.name}-s3-csi"
  attach_mountpoint_s3_csi_policy = true
  mountpoint_s3_csi_bucket_arns = [
    "arn:aws:s3:::model-weights-386865647718-us-east-1-an",
    local.benchmark_results_bucket_arn,
  ]
  mountpoint_s3_csi_bucket_path_arns = [
    "arn:aws:s3:::model-weights-386865647718-us-east-1-an/*",
    "${local.benchmark_results_bucket_arn}/*",
  ]

  associations = {
    this = {
      cluster_name    = local.name
      namespace       = "kube-system"
      service_account = "s3-csi-driver-sa"
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

  tags = var.tags
}

module "aws_efs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                      = "${local.name}-efs-csi"
  attach_aws_efs_csi_policy = true

  associations = {
    this = {
      cluster_name    = local.name
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
    }
  }

  tags = var.tags
}

module "aws_teamcity_server_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "${local.name}-teamcity"
  additional_policy_arns = {
    "arn:aws:iam::aws:policy/AmazonS3FullAccess" : "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  }
  associations = {
    this = {
      cluster_name    = local.name
      namespace       = "cicd"
      service_account = "teamcity-server"
    }
  }

  tags = var.tags
}

module "aws_teamcity_agent_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "${local.name}-teamcity-agent"
  additional_policy_arns = {
    "EC2InstanceProfileForImageBuilderECRContainerBuilds" = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  }

  # Bound to the agent pods' own SA rather than teamcity-server's -- the
  # server doesn't push images, build agents do, so the ECR-capable role
  # should only be reachable by the ephemeral agent pods.
  associations = {
    this = {
      cluster_name    = local.name
      namespace       = "cicd"
      service_account = "teamcity-agent"
    }
  }

  tags = var.tags
}
