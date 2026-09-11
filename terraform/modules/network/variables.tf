variable "name_prefix" {
  type        = string
  description = "Prefixo usado no Name tag dos recursos (ex: togglemaster-dev)"
}

variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS que vai usar essas subnets (para as tags kubernetes.io/*)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block da VPC"
}

variable "az_count" {
  type        = number
  description = "Quantidade de AZs a usar (gera N subnets públicas e N privadas)"
  default     = 2
}
