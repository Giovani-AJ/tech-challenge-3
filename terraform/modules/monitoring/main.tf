## Prometheus + Grafana (kube-prometheus-stack): observabilidade do cluster e dos
## 5 microsserviços. O ingress-nginx já expõe métricas Prometheus desde que foi
## instalado (controller.metrics.enabled=true, módulo ingress-nginx) mas, até
## este módulo existir, nada consumia isso — ver o ServiceMonitor em
## gitops/cluster-resources/, que é quem liga essa ponta.
##
## Sem Alertmanager (não tem pra quem alertar num projeto acadêmico) e sem
## armazenamento persistente (Prometheus/Grafana usam o padrão do chart, sem PVC):
## dados somem se o pod reiniciar, o que é aceitável aqui — o objetivo é
## observabilidade ao vivo na demonstração, não retenção histórica.

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  # Por padrão o Prometheus só descobre ServiceMonitor criado pelo próprio chart
  # (com o label de release dele). Sem isso, o ServiceMonitor do ingress-nginx
  # (gitops/cluster-resources/) nunca seria descoberto.
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Explícito por segurança: o padrão do chart já é ClusterIP, mas depois do
  # imprevisto com o NLB do ingress-nginx, preferimos não depender de default
  # implícito pra evitar qualquer tentativa de criar mais um Load Balancer.
  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }
}
