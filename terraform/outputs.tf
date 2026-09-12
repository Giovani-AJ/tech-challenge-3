output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "AWS_GITHUB_ACTIONS_ROLE_ARN — configure como variável/secret em cada um dos 5 repos"
  value       = module.github_oidc.role_arn
}

output "rds_endpoints" {
  value = {
    auth      = module.auth_db.endpoint
    flag      = module.flag_db.endpoint
    targeting = module.targeting_db.endpoint
  }
}

output "rds_secret_names" {
  description = "Nomes dos segredos no Secrets Manager, usados nos ExternalSecret do repo GitOps"
  value = {
    auth      = module.auth_db.secret_name
    flag      = module.flag_db.secret_name
    targeting = module.targeting_db.secret_name
  }
}

output "auth_master_key_secret_name" {
  value = aws_secretsmanager_secret.auth_master_key.name
}

output "evaluation_service_api_key_secret_name" {
  value = aws_secretsmanager_secret.evaluation_service_api_key.name
}

output "redis_endpoint" {
  value = "${module.redis.endpoint}:${module.redis.port}"
}

output "dynamodb_table_name" {
  value = module.analytics_table.table_name
}

output "sqs_queue_url" {
  value = module.evaluation_queue.queue_url
}

output "evaluation_service_irsa_role_arn" {
  value = module.evaluation_service_irsa.role_arn
}

output "analytics_service_irsa_role_arn" {
  value = module.analytics_service_irsa.role_arn
}

output "eso_irsa_role_arn" {
  value = module.eso_irsa.role_arn
}

output "ingress_load_balancer_hostname" {
  description = "Hostname do NLB do ingress-nginx (pode levar alguns minutos pra existir após o apply)"
  value       = module.ingress_nginx.load_balancer_hostname
}

output "grafana_access_hint" {
  description = "Grafana fica atrás de ClusterIP (mesmo motivo do ArgoCD: evitar outro Load Balancer) — acesse via port-forward"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}
