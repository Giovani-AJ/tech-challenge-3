variable "name_prefix" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "Nome do repositório (monorepo, sem a org) autorizado a assumir a role via OIDC"
}

variable "ecr_repository_arns" {
  type = list(string)
}
