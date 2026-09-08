# The VPC and its security groups are shared to this account via RAM, but the
# Shared Security Group feature only supports an allowlist of services and RDS
# is not on it -- attaching a shared group fails with "is owned by another
# account". Participants may create their own groups in a shared VPC, so the DB
# gets one owned here. See:
# https://docs.aws.amazon.com/vpc/latest/userguide/security-group-sharing.html
#
# The VPC id is read off a subnet rather than passed in, so the shared VPC id
# does not have to be plumbed through as another variable.
data "aws_subnet" "selected" {
  id = var.subnets[0]
}

module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "${var.db_identifier}-sg"
  description = "Security group for the ${var.db_identifier} RDS instance"
  vpc_id      = data.aws_subnet.selected.vpc_id
  create_sg   = true

  # Referencing a shared group as a rule source is a different operation from
  # associating it with the instance, so it is not subject to that allowlist.
  ingress_with_source_security_group_id = [
    for sg_id in var.ingress_security_group_ids : {
      from_port                = var.db_port
      to_port                  = var.db_port
      protocol                 = "tcp"
      source_security_group_id = sg_id
      description              = "Database traffic from ${sg_id}"
    }
  ]

  ingress_with_cidr_blocks = [
    for cidr in var.ingress_cidr_blocks : {
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      cidr_blocks = cidr
      description = "Database traffic from ${cidr}"
    }
  ]

  tags = var.tags
}

resource "aws_db_instance" "oltp" {
  allocated_storage          = var.allocated_storage
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  backup_retention_period    = 7
  db_subnet_group_name       = var.subnet_group_name
  engine                     = var.db_engine
  engine_version             = var.db_engine_version
  identifier                 = var.db_identifier
  instance_class             = var.db_instance_class
  multi_az                   = true
  password                   = var.master_password
  username                   = var.master_username
  storage_encrypted          = var.encrypt_storage
  tags                       = var.tags
  apply_immediately          = true
  vpc_security_group_ids     = [module.rds_security_group.security_group_id]
  storage_type               = var.storage_type

  timeouts {
    create = "3h"
    delete = "3h"
    update = "3h"
  }

  depends_on = [aws_db_subnet_group.this]
}

resource "aws_db_subnet_group" "this" {
  count      = var.create_subnet_group ? 1 : 0
  name       = var.subnet_group_name == null ? "${var.db_identifier}-db-subnet-group" : var.subnet_group_name
  subnet_ids = var.subnets

  tags = var.tags
}
