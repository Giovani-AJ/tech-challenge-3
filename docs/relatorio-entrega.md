# Relatório de Entrega — Tech Challenge Fase 3 (ToggleMaster)

> Preencher antes de exportar como PDF para a entrega.

## Participantes

- [Nome completo] — [e-mail/RA]
- ...

## Links

- Vídeo de demonstração: [link]
- Repositórios:
  - Infra (Terraform): https://github.com/Giovani-AJ/togglemaster-infra
  - GitOps: https://github.com/Giovani-AJ/togglemaster-gitops
  - auth-service: https://github.com/Giovani-AJ/auth-service
  - flag-service: https://github.com/Giovani-AJ/flag-service
  - targeting-service: https://github.com/Giovani-AJ/targeting-service
  - evaluation-service: https://github.com/Giovani-AJ/evaluation-service
  - analytics-service: https://github.com/Giovani-AJ/analytics-service

## Resumo dos desafios encontrados e decisões tomadas

> Sugestão de tópicos para desenvolver (ver `docs/ARQUITETURA.md` para o racional
> completo de cada decisão):

- Por que External Secrets Operator + Secrets Manager em vez de Secret estático no
  manifesto (resolve o problema de credencial em texto plano citado no desafio).
- Por que OIDC (GitHub Actions → AWS e Pod → AWS) em vez de access key fixa.
- Como o gate de segurança (Trivy + gosec/bandit) foi configurado para bloquear em
  vulnerabilidade crítica, e o que aconteceu ao testar isso propositalmente.
- Alguma dificuldade específica da conta AWS pessoal / limites de IAM / quota de
  vCPU para o EKS, se houve.
- Trade-offs assumidos por custo/tempo de laboratório (NAT único, Redis sem auth,
  sem Ingress público) — ver "Limitações conhecidas" em `docs/ARQUITETURA.md`.

## Print da estimativa de custos da AWS

> Inserir aqui a imagem/print do Cost Explorer ou AWS Pricing Calculator.
