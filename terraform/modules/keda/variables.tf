variable "namespace" {
  type    = string
  default = "keda"
}

variable "service_account_name" {
  type    = string
  default = "keda-operator"
}

variable "chart_version" {
  type    = string
  default = "2.17.2"
}

variable "irsa_role_arn" {
  type = string
}
