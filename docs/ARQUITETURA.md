# Arquitetura — ToggleMaster (Fase 3)

## Visão geral

```
GitHub (5 repos de serviço)          GitHub (togglemaster-gitops)
  auth / flag / targeting /              apps/<service>/*.yaml
  evaluation / analytics                 argocd-applications/*.yaml
        |  CI (build, lint, SAST/SCA,          ^
        |  docker build+scan, push ECR)        | ArgoCD sincroniza
        └──────► atualiza tag no gitops ───────┘
                                                 |
                                                 v
                                          Cluster EKS
                          ┌─────────────────────────────────────┐
                          │  argocd (namespace)                  │
                          │  external-secrets (namespace)        │
                          │  toggle-master (namespace)           │
                          │    auth / flag / targeting /         │
                          │    evaluation / analytics (pods)     │
                          └─────────────────────────────────────┘
                                     |          |          |
                                RDS x3      ElastiCache   SQS + DynamoDB
                              (Postgres)      (Redis)     (via IRSA)
```

## Por que essas escolhas

- **Terraform modularizado** (`terraform/modules/*`): cada módulo é uma unidade
  provisionável isoladamente (network, eks, rds, elasticache, dynamodb, sqs, ecr,
  github-oidc, irsa, external-secrets, argocd) — reflete o requisito de "código
  organizado, preferencialmente usando módulos".
- **OIDC em vez de access key** (CI→AWS e Pod→AWS): elimina credencial de longa
  duração tanto no GitHub quanto no cluster. É a resposta direta ao problema do
  enunciado ("credenciais em arquivo de texto sem segurança").
- **External Secrets Operator + Secrets Manager**: a senha do RDS nunca é gerada
  manualmente nem digitada — o Terraform gera com `random_password`, guarda no
  Secrets Manager, e o ESO materializa como K8s Secret via IRSA. Nenhum arquivo do
  repositório de GitOps contém uma credencial em texto puro ou base64 "disfarçado"
  (diferença importante: base64 não é criptografia, só codificação).
- **GitOps com ArgoCD**: elimina o `kubectl apply` manual dos desenvolvedores citado
  como problema no enunciado. O cluster nunca é alterado diretamente — só o
  repositório `togglemaster-gitops`, e o ArgoCD converge o estado automaticamente.
- **Pipeline com gate de segurança**: Trivy (SCA, filesystem e imagem) e
  gosec/bandit (SAST) rodam antes do build da imagem; `exit-code: 1` em
  vulnerabilidade `CRITICAL`/alta confiança interrompe o pipeline, cumprindo a
  "regra de bloqueio" do desafio.

## Limitações conhecidas / próximos passos

- NAT Gateway único (não 1 por AZ) — economia de custo no laboratório, mas é
  um ponto único de falha de rede de saída.
- Redis sem AUTH/TLS — igual ao ambiente original da Fase 2; em produção real
  seria preciso habilitar `transit_encryption_enabled` + auth token.
- Sem Ingress/ALB — acesso aos serviços via `kubectl port-forward` para a demo;
  adicionar um `ingress-nginx` ou AWS Load Balancer Controller é o próximo passo
  natural para expor a API publicamente.
- `techchall2/auth-service/init-db-job.yaml` e os `*-infra.yaml` antigos (Fase 2)
  ainda têm credenciais reais em texto/base64 no histórico do git desses
  repositórios — vale trocar a senha do RDS que foi exposta e, se possível,
  reescrever o histórico ou pelo menos não reutilizar essa senha em nenhum
  ambiente novo.
