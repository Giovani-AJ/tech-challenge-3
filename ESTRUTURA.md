# Estrutura do projeto — tech-challenge-3

Este é o repositório **único** do projeto ToggleMaster (Tech Challenge Fase 3):
infraestrutura, código dos 5 microsserviços, pipeline de CI/DevSecOps e manifests
de GitOps, tudo junto. Este documento existe pra você (ou qualquer pessoa retomando
o trabalho, inclusive em outra máquina) entender rapidamente onde cada coisa mora e
por quê.

> Este projeto teve uma versão anterior espalhada em 7 repositórios separados
> (`togglemaster-infra`, `togglemaster-gitops` + 5 repos de serviço). Foi consolidado
> aqui por organização. Os repositórios antigos continuam existindo no GitHub, mas
> não são mais usados — nada neles é atualizado a partir de agora.

## Por que tudo num repositório só (e por que isso ainda funciona com GitOps)

Separar infra/gitops/código em repositórios diferentes é uma prática comum, mas o
próprio enunciado do desafio permite explicitamente a alternativa de monorepo pro
GitOps ("crie um repositório separado **ou uma pasta separada no monorepo**"). Um
monorepo funciona igual aqui porque:

- O **ArgoCD** não liga pra estrutura do repositório inteiro — cada `Application`
  aponta pra um `path:` específico (`gitops/apps/<service>`), então ele só reage a
  mudanças nessa pasta, mesmo que o resto do repositório mude o tempo todo.
- O **CI de cada serviço** (`.github/workflows/ci-<service>.yml`) só dispara quando
  algo dentro de `services/<service>/**` muda (`paths:` no trigger do workflow) —
  então um push no `auth-service` não builda os outros 4.
- O job final de cada pipeline (`update-gitops`) agora só precisa commitar e dar
  push **no mesmo repositório** — não precisa mais de um Personal Access Token pra
  autenticar num repositório separado, o token padrão do GitHub Actions
  (`GITHUB_TOKEN`, com permissão `contents: write`) já resolve.

O `.github/workflows/` **precisa** ficar na raiz do repositório — o GitHub não lê
workflows de dentro de subpastas, mesmo em monorepo. Por isso os 5 arquivos de CI
vivem soltos ali, cada um com o nome do serviço, em vez de dentro de
`services/<service>/.github/`.

## Estrutura de pastas

```
terraform/
  bootstrap/              # cria o bucket S3 do backend remoto — roda 1x, ANTES de tudo
  main.tf                 # ponto de entrada: instancia todos os módulos abaixo
  variables.tf              # inputs (região, tamanhos de instância, nomes, etc.)
  outputs.tf                  # ARNs, endpoints, URLs — usados pra configurar o gitops/ e os secrets do GitHub
  providers.tf                  # AWS + Kubernetes/Helm (autenticação "exec" via `aws eks get-token`)
  backend.hcl.example             # copie pra backend.hcl (git-ignorado) com o bucket do bootstrap
  modules/
    network/              # VPC, subnets públicas/privadas, IGW, NAT Gateway
    eks/                  # Cluster EKS + node group + OIDC provider + acesso admin explícito
    rds/                  # 1 instância RDS Postgres + Secrets Manager (instanciado 3x: auth/flag/targeting)
    elasticache/          # Redis (usado pelo evaluation-service)
    dynamodb/             # Tabela ToggleMasterAnalytics
    sqs/                  # Fila de eventos de avaliação + DLQ
    ecr/                  # 5 repositórios de imagem Docker
    github-oidc/          # OIDC do GitHub Actions -> role com permissão só de ECR (confia neste monorepo)
    irsa/                  # módulo genérico: IAM Role for Service Account (reusado 3x)
    external-secrets/     # Instala o ESO via Helm (Secrets Manager -> K8s Secret)
    argocd/                # Instala o ArgoCD via Helm

gitops/
  apps/<service>/          # ConfigMap, ExternalSecret, ServiceAccount, Deployment+Service por serviço
  cluster-resources/        # Namespace + ClusterSecretStore (sync-wave antes dos apps)
  argocd-applications/      # manifests Application do ArgoCD (kubectl apply, não é gerenciado por Helm)

services/
  auth-service/            # Go — autenticação/API keys
  flag-service/             # Python/Flask — CRUD de feature flags
  targeting-service/         # Python/Flask — regras de segmentação
  evaluation-service/         # Go — avalia flags (Redis + SQS)
  analytics-service/           # Python/Flask — consome SQS, grava no DynamoDB

.github/workflows/
  ci-auth-service.yml       # build/test -> lint -> SAST/SCA -> docker build+scan+push -> update gitops/
  ci-flag-service.yml       # (mesmo padrão, filtrado por path)
  ci-targeting-service.yml
  ci-evaluation-service.yml
  ci-analytics-service.yml

docs/
  RUNBOOK.md                # passo a passo operacional, do zero até os serviços rodando
  ARQUITETURA.md            # decisões de design e trade-offs assumidos
  relatorio-entrega.md      # rascunho do relatório de entrega da Fase 3

README.md
ESTRUTURA.md                # este arquivo
```

## Estado atual (setembro/2026)

A infraestrutura já está provisionada e rodando na AWS (conta pessoal, `681447159486`,
região `us-east-1`).

- [x] Terraform aplicado (VPC, EKS 1.36, 3 RDS, Redis, DynamoDB, SQS, 5 ECR, IAM/OIDC)
- [x] ArgoCD e External Secrets Operator rodando no cluster
- [x] Tabelas dos 3 bancos inicializadas
- [x] OIDC do GitHub Actions atualizado pra confiar neste monorepo (`tech-challenge-3`)
- [x] Credencial do ArgoCD pro repositório privado atualizada pra apontar pra cá
- [x] As 6 `Application` do ArgoCD atualizadas (repoURL + path novos)

Pendente:

- [ ] Publicar este repositório no GitHub (`Giovani-AJ/tech-challenge-3`, privado)
- [ ] Configurar `AWS_GITHUB_ACTIONS_ROLE_ARN` como **repository variable** — uma
      vez só, já que agora é um repositório único (valor:
      `arn:aws:iam::681447159486:role/togglemaster-dev-github-actions-ci`)
- [ ] Primeiro push real disparando o pipeline de CI/DevSecOps (os pods atualmente
      estão em `ErrImagePull` porque a tag `v1.0.0-init` nunca foi construída de verdade)
- [ ] Bootstrap da `SERVICE_API_KEY` do evaluation-service
- [ ] Vídeo de demonstração + relatório de entrega

## Retomando em outra máquina

1. Clone só este repositório (não precisa mais dos outros 6)
2. Instale: Terraform, AWS CLI v2, kubectl, helm, jq
3. Configure a credencial AWS do usuário `terraform-cli` (`aws configure`)
4. Copie `terraform/backend.hcl.example` para `terraform/backend.hcl` com o bucket
   `togglemaster-tfstate-56bbf220` (não é segredo, só configuração)
5. `cd terraform && terraform init -backend-config=backend.hcl` — reconecta ao
   estado que já existe no S3, sem recriar nada
6. `aws eks update-kubeconfig --region us-east-1 --name togglemaster-dev-eks`
