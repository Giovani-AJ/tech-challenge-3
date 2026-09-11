## Instala o External Secrets Operator via Helm. O service account criado aqui é
## anotado com a IAM Role (IRSA) que tem permissão de ler os segredos do
## Secrets Manager — é essa role que faz a ponte "Secrets Manager -> K8s Secret"
## sem nenhuma credencial em texto plano em manifesto nenhum.

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.irsa_role_arn
  }
}

# O ClusterSecretStore (CRD do próprio chart, que só existe depois deste helm_release)
# não é criado aqui de propósito: kubernetes_manifest exigiria a CRD já presente no
# plan, gerando uma corrida com o helm_release na primeira apply. Ele vive versionado
# no repo de GitOps (gitops/cluster-resources/cluster-secret-store.yaml) e é aplicado
# pelo ArgoCD depois que o ESO já está de pé — ver docs/RUNBOOK.md.
