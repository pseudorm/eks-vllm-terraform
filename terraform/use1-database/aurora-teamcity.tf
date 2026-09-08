resource "aws_rds_cluster" "teamcity" {
  cluster_identifier = "teamcity-aurora-dev"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "17.7"

  database_name   = "teamcity"
  master_username = "teamcity_admin"
  # AWS generates and manages the master password in Secrets Manager instead
  # of a plaintext value in tfvars -- fetch it after apply via
  # `aws secretsmanager get-secret-value --secret-id <master_user_secret_arn>`.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  storage_encrypted         = true
  backup_retention_period   = 7
  apply_immediately         = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "teamcity-aurora-dev-final"

  serverlessv2_scaling_configuration {
    min_capacity = 0
    max_capacity = 4
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "teamcity" {
  identifier         = "teamcity-aurora-dev-1"
  cluster_identifier = aws_rds_cluster.teamcity.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.teamcity.engine
  engine_version     = aws_rds_cluster.teamcity.engine_version

  tags = var.tags
}

output "teamcity_aurora_endpoint" {
  description = "Writer endpoint for the TeamCity Aurora Serverless v2 cluster"
  value       = aws_rds_cluster.teamcity.endpoint
}

output "teamcity_aurora_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the generated master password for the TeamCity Aurora cluster"
  value       = aws_rds_cluster.teamcity.master_user_secret[0].secret_arn
}
