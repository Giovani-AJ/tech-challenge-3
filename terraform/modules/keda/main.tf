## KEDA (Kubernetes Event-driven Autoscaling): permite o analytics-service escalar
## direto pela profundidade da fila SQS (de 0 a N pods), em vez de depender de CPU
## como proxy indireto de carga. É a alternativa "recomendada para conta pessoal"
## citada no desafio da Fase 2, no lugar do workaround de HPA por CPU que o
## ambiente AWS Academy exige (não pode criar a IRSA que o KEDA precisa).

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "serviceAccount.operator.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.operator.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.irsa_role_arn
  }
}
