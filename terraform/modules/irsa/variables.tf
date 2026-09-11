variable "role_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type        = string
  description = "URL do provider OIDC sem o https:// (ex: oidc.eks.us-east-1.amazonaws.com/id/XXXX)"
}

variable "policy_json" {
  type = string
}
