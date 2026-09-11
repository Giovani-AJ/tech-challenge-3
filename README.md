# tech-challenge-3 — ToggleMaster (Pós DevOps, Tech Challenge Fase 3)

Monorepo com infraestrutura como código, os 5 microsserviços do ToggleMaster, pipeline
DevSecOps e GitOps — tudo num só repositório, substituindo o provisionamento manual
da Fase 2.

Veja `ESTRUTURA.md` para o mapa completo de pastas e o racional de cada decisão, e
`docs/RUNBOOK.md` para o passo a passo operacional (do zero até os serviços rodando).

## Estrutura

```
terraform/          # IaC: rede, EKS, RDS x3, Redis, DynamoDB, SQS, ECR, OIDC, ArgoCD, ESO
gitops/              # manifests que o ArgoCD sincroniza (Application aponta pra cá)
services/
  auth-service/        # Go
  flag-service/         # Python/Flask
  targeting-service/     # Python/Flask
  evaluation-service/     # Go
  analytics-service/       # Python/Flask
.github/workflows/    # 1 workflow de CI por serviço, filtrado por path
docs/                # RUNBOOK, ARQUITETURA, relatório de entrega
```

## Por onde começar

Siga `docs/RUNBOOK.md`. Resumo rápido do que já está feito e do que falta em
`ESTRUTURA.md` (seção "Estado atual").
