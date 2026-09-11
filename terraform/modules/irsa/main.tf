## Módulo genérico de IRSA (IAM Role for Service Account): dado um Service Account
## do Kubernetes (namespace + nome), cria uma IAM Role que ele pode assumir via o
## provider OIDC do EKS, com a policy passada em var.policy_json.
##
## Reaproveitado para: External Secrets Operator (ler Secrets Manager),
## evaluation-service (mandar mensagem no SQS) e analytics-service (ler SQS + gravar DynamoDB).

resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
