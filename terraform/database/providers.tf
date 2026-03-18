
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
    key          = "rds-ai-platform.tfstate"
    region       = "ap-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-east-1"
}
