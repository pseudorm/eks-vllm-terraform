resource "aws_db_instance" "transaction_db" {
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

  timeouts {
    create = "3h"
    delete = "3h"
    update = "3h"
  }
}
