data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "node_subnets" {
  for_each = toset(var.node_subnet_ids)
  id       = each.value
}

data "aws_security_group" "node_security_group" {
  id = var.node_security_group_id
}
