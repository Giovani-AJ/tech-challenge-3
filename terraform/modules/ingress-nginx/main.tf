## Instala o ingress-nginx via Helm, expondo os 5 microsserviços publicamente
## através de um Network Load Balancer (NLB). Mesma ferramenta usada na Fase 2,
## agora provisionada como código em vez de instalação manual no console.

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # NLB em vez do Classic ELB padrão: mais barato e sem cobrança por LCU ociosa.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
}
