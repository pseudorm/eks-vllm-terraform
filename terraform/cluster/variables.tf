variable "vpc_id" {
  description = "The VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "The subnet IDs where the EKS cluster will be deployed"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "The subnet IDs where the EKS nodes will be deployed"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "The security group ID for the EKS cluster"
  type        = string
}

variable "node_security_group_id" {
  description = "The security group ID for the EKS nodes"
  type        = string

}

variable "tags" {
  type        = map(any)
  description = "A map of tags to assign to all resources created by this module"
}
