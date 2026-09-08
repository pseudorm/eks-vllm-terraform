resource "aws_efs_file_system" "teamcity" {
  encrypted = true
  tags = merge(var.tags, {
    Name = "${local.name}-teamcity"
  })
}

resource "aws_efs_mount_target" "teamcity" {
  for_each = toset(var.node_subnet_ids)

  file_system_id  = aws_efs_file_system.teamcity.id
  subnet_id       = each.value
  security_groups = [var.efs_security_group_id]
}

output "efs_file_system_id" {
  description = "EFS filesystem ID for the teamcity-server-data PVC's efs StorageClass"
  value       = aws_efs_file_system.teamcity.id
}
