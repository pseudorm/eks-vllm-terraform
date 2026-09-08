variable "allocated_storage" {
  description = "The allocated storage size in GB"
  type        = number
  default     = 20
}

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window"
  type        = bool
  default     = true
}

variable "create_subnet_group" {
  type    = bool
  default = false
}

variable "subnet_group_name" {
  description = "The name of the DB subnet group"
  type        = string
}

variable "subnets" {
  type    = list(string)
  default = []
}

variable "db_engine" {
  description = "The database engine to use"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "The engine version to use"
  type        = string
}

variable "db_identifier" {
  description = "The name of the RDS instance"
  type        = string
}

variable "db_instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "master_username" {
  description = "Username for the master DB user"
  type        = string
}

variable "master_password" {
  description = "Password for the master DB user"
  type        = string
  sensitive   = true
}

variable "encrypt_storage" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "ingress_security_group_ids" {
  description = "Security group IDs allowed to reach the DB on db_port. May include groups owned by the network account, since referencing a shared group as a rule source is permitted."
  type        = list(string)
  default     = []
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the DB on db_port. Use when a source security group reference is not usable."
  type        = list(string)
  default     = []
}

variable "db_port" {
  description = "Port the database engine listens on"
  type        = number
  default     = 5432
}

variable "storage_type" {
  description = "Type of volume storage"
  type        = string
  default     = "gp3"
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
