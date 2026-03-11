
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "phcheng-ap-east-1-terraform-states"
    key          = "eks-ai.tfstate"
    region       = "ap-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-east-1"
}

provider "helm" {
  kubernetes = {
    host                   = module.aws_eks_ai.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aws_eks_ai.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.aws_eks_ai.cluster_name]
    }
  }
}
