## metrics-server: fornece as métricas de CPU/memória que o HorizontalPodAutoscaler
## de cada serviço usa pra decidir quando escalar. Sem isso, o HPA fica com
## "unknown" no `kubectl get hpa` e nunca escala nada.

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  namespace  = "kube-system"
}
