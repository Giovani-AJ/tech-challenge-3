## Instala o ArgoCD via Helm no cluster EKS. O Application/ApplicationSet que
## aponta pro repo de GitOps fica versionado em gitops/argocd-applications/
## (aplicado uma vez via kubectl, ou apontado por um "app of apps" — ver RUNBOOK).

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  # ClusterIP + port-forward é suficiente para a demo (evita custo de mais um LoadBalancer).
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}
