## Bootstrap: cria o bucket S3 que vai guardar o terraform.tfstate do projeto principal.
## Roda com backend local (é o único módulo que não usa backend remoto, por razões óbvias
## de ovo-e-galinha: o bucket do backend remoto ainda não existe).
##
## Uso:
##   cd terraform/bootstrap
##   terraform init
##   terraform apply
##
## Depois disso, preencha terraform/backend.hcl com o nome do bucket gerado e rode
## `terraform init -backend-config=../backend.hcl` no diretório terraform/ raiz.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "togglemaster"
}

# Sufixo aleatório porque nomes de bucket S3 são globalmente únicos.
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${random_id.suffix.hex}"

  # Nunca destrua sem querer o bucket que guarda o estado de toda a infra.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "backend_hcl" {
  description = "Cole isto em terraform/backend.hcl"
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.tfstate.bucket}"
    key          = "togglemaster/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
