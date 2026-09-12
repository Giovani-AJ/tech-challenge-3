## O hostname do NLB só existe depois que a AWS termina de provisionar (pode levar
## alguns minutos). Se vier vazio logo após o apply, rode `terraform refresh` ou
## `kubectl get svc -n ingress-nginx` depois de esperar um pouco.
data "kubernetes_service" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [helm_release.ingress_nginx]
}

output "load_balancer_hostname" {
  value = try(data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].hostname, "")
}
