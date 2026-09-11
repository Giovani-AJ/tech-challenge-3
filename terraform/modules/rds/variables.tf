variable "identifier" {
  type        = string
  description = "Identificador único da instância RDS (ex: togglemaster-dev-auth-db)"
}

variable "service_name" {
  type        = string
  description = "Nome do microsserviço dono deste banco (ex: auth-service)"
}

variable "db_name" {
  type    = string
  default = "postgres"
}

variable "master_username" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type        = string
  description = "Security group dos worker nodes do EKS, liberado para falar com o banco"
}

variable "secret_prefix" {
  type        = string
  description = "Prefixo dos segredos no Secrets Manager (ex: togglemaster/dev)"
}
