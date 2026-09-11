# Runbook — ToggleMaster (Tech Challenge Fase 3)

Passo a passo completo, do zero até os 5 microsserviços rodando via GitOps/ArgoCD.

## 0. Pré-requisitos

- Conta AWS pessoal com credenciais configuradas (`aws configure` ou variáveis de ambiente)
- Terraform >= 1.6, AWS CLI v2, kubectl, helm, git
- Repositórios sob a sua conta pessoal `github.com/Giovani-AJ/*` (não a da Texlink,
  nem a org `FIAP-TCs` do material da turma): os 5 microsserviços já têm um remote
  `origin` local apontando pra lá (o `upstream` continua sendo o `FIAP-TCs/*`
  original, só como referência de leitura — nunca damos push nele)

## 1. Bootstrap do backend remoto (S3)

```bash
cd terraform/bootstrap
terraform init
terraform apply
terraform output backend_hcl   # copie a saída para terraform/backend.hcl
```

## 2. Provisionar a infraestrutura

```bash
cd ../            # terraform/
cp backend.hcl.example backend.hcl   # cole o conteúdo do passo 1
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Isso cria: VPC/subnets/NAT, cluster EKS + node group, 3 RDS Postgres, 1 ElastiCache
Redis, 1 tabela DynamoDB, 1 fila SQS (+ DLQ), 5 repositórios ECR, o provider OIDC +
role do GitHub Actions, o provider OIDC do EKS, as IAM roles (IRSA) do ESO e dos
serviços evaluation/analytics, e instala ArgoCD + External Secrets Operator via Helm.

> **Gotcha conhecido (Terraform + EKS + Kubernetes/Helm providers no mesmo apply):**
> os providers `kubernetes`/`helm` (`providers.tf`) só conseguem se autenticar depois
> que o cluster EKS já existe. Na primeira aplicação, isso normalmente funciona porque
> o Terraform ordena a criação pelo grafo de dependências, mas se o `apply` falhar
> reclamando de conexão recusada/DNS ao tentar criar o `helm_release`/`kubernetes_namespace`,
> rode em duas etapas:
> ```bash
> terraform apply -target=module.eks
> terraform apply
> ```

Guarde os outputs — eles alimentam os próximos passos:

```bash
terraform output
```

## 3. Inicializar os bancos (tabelas)

Os scripts já existem em `<serviço>/db/init.sql` no repositório de cada microsserviço.
Busque a credencial no Secrets Manager (nunca hardcode a senha em lugar nenhum):

```bash
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id togglemaster/dev/togglemaster-dev-auth-db --query SecretString --output text)
DATABASE_URL=$(echo "$SECRET" | jq -r .DATABASE_URL)
psql "$DATABASE_URL" -f ../tech-chall2/auth-service/db/init.sql
```

Repita trocando `auth-db`/`auth-service` por `flag-db`/`flag-service` e
`targeting-db`/`targeting-service`. O acesso só funciona de dentro da VPC (os
Security Groups liberam apenas os nodes do EKS) — rode isso de um pod temporário no
cluster (`kubectl run -it --rm psql --image=postgres:15-alpine -- sh`) ou via um
bastion/VPN, não direto da sua máquina.

## 4. Preencher os placeholders do repositório de GitOps

Antes do primeiro push, substitua os placeholders em `gitops/` pelos valores reais
dos outputs do Terraform:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint | cut -d: -f1)
SQS_URL=$(terraform output -raw sqs_queue_url)
EVAL_ROLE_ARN=$(terraform output -raw evaluation_service_irsa_role_arn)
ANALYTICS_ROLE_ARN=$(terraform output -raw analytics_service_irsa_role_arn)

cd ../gitops
grep -rl '<AWS_ACCOUNT_ID>' apps | xargs sed -i "s|<AWS_ACCOUNT_ID>|$ACCOUNT_ID|g"
sed -i "s|<REDIS_ENDPOINT>|$REDIS_ENDPOINT|" apps/evaluation-service/configmap.yaml
sed -i "s|<SQS_QUEUE_URL>|$SQS_URL|" apps/evaluation-service/configmap.yaml apps/analytics-service/configmap.yaml
sed -i "s|<EVALUATION_SERVICE_ROLE_ARN>|$EVAL_ROLE_ARN|" apps/evaluation-service/serviceaccount.yaml
sed -i "s|<ANALYTICS_SERVICE_ROLE_ARN>|$ANALYTICS_ROLE_ARN|" apps/analytics-service/serviceaccount.yaml
```

## 5. Criar e publicar o repositório de GitOps

Não há `gh` CLI instalado nesta máquina, então o caminho é o manual, com a
**sua conta pessoal** (`Giovani-AJ`), nunca a da Texlink:

1. Crie o repositório **privado** `togglemaster-gitops` pela interface do GitHub,
   já logado na conta pessoal (github.com/new).
2. Publique o conteúdo já preparado em `gitops/`:

```bash
cd gitops
git init
git config credential.https://github.com.username Giovani-AJ
git add .
git commit -m "chore: manifests iniciais do ToggleMaster"
git branch -M main
git remote add origin https://github.com/Giovani-AJ/togglemaster-gitops.git
git push -u origin main
```

O `git push` vai abrir o prompt de login do Windows — entre com `Giovani-AJ`.

## 6. Publicar os 5 repositórios de microsserviço na sua conta pessoal

Cada repositório local em `tech-chall2/<service>` já tem dois remotes configurados:
`origin` → `github.com/Giovani-AJ/<service>` (sua conta pessoal — ainda não existe no
GitHub) e `upstream` → `github.com/FIAP-TCs/<service>` (original da turma, só leitura,
nunca leva push). Para cada um dos 5 serviços:

1. Crie o repositório **privado** vazio pela interface do GitHub (github.com/new),
   com exatamente o mesmo nome (`auth-service`, `flag-service`, `targeting-service`,
   `evaluation-service`, `analytics-service`), logado como `Giovani-AJ`.
2. Publique o conteúdo local (que já inclui o `.github/workflows/ci.yml` adicionado
   nesta sessão e as correções de build):

```bash
cd "C:\Users\Giovani\Desktop\Estudos\Estudos\tech-chall2\tech-chall2\<service>"
git add -A
git commit -m "chore: adiciona pipeline de CI/DevSecOps"
git push -u origin main   # login: Giovani-AJ
```

3. Em Settings → Secrets and variables → Actions **desse repositório pessoal**:
   - **Variable** `AWS_GITHUB_ACTIONS_ROLE_ARN` = output `github_actions_role_arn`
   - **Secret** `GITOPS_PAT` = um Personal Access Token (fine-grained, escopo apenas
     `contents: write` no repo `togglemaster-gitops`) — é o que permite o workflow de
     CI de cada serviço dar commit/push no repo de GitOps

Repita para os 5 serviços.

## 7. Aplicar as Applications do ArgoCD

```bash
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw cluster_name)
kubectl apply -f gitops/argocd-applications/cluster-resources.yaml
kubectl apply -f gitops/argocd-applications/auth-service.yaml
kubectl apply -f gitops/argocd-applications/flag-service.yaml
kubectl apply -f gitops/argocd-applications/targeting-service.yaml
kubectl apply -f gitops/argocd-applications/evaluation-service.yaml
kubectl apply -f gitops/argocd-applications/analytics-service.yaml
```

## 8. Acessar o ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443
# https://localhost:8080  (usuário: admin)
```

## 9. Testar os serviços

```bash
kubectl -n toggle-master port-forward svc/auth-service 8001:8001
curl -X POST http://localhost:8001/admin/keys \
  -H "Authorization: Bearer $(aws secretsmanager get-secret-value --secret-id togglemaster/dev/togglemaster-dev-auth-service-app --query SecretString --output text | jq -r .MASTER_KEY)" \
  -H "Content-Type: application/json" -d '{"name":"demo"}'
```

## 9b. Bootstrap da chave que o evaluation-service usa (SERVICE_API_KEY)

O `evaluation-service` chama `flag-service` e `targeting-service` como cliente
autenticado — precisa de uma API key válida, que só pode ser emitida pelo
`auth-service` já rodando (não dá pra gerar isso via Terraform). Faça uma vez:

```bash
MASTER_KEY=$(aws secretsmanager get-secret-value \
  --secret-id togglemaster/dev/togglemaster-dev-auth-service-app \
  --query SecretString --output text | jq -r .MASTER_KEY)

kubectl -n toggle-master port-forward svc/auth-service 8001:8001 &
NEW_KEY=$(curl -s -X POST http://localhost:8001/admin/keys \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"evaluation-service"}' | jq -r .key)

aws secretsmanager put-secret-value \
  --secret-id togglemaster/dev/togglemaster-dev-evaluation-service-api-key \
  --secret-string "{\"SERVICE_API_KEY\":\"$NEW_KEY\"}"
```

O `ExternalSecret` do evaluation-service tem `refreshInterval: 15m`; para não
esperar, force a resincronização: `kubectl -n toggle-master annotate externalsecret
evaluation-secret force-sync=$(date +%s) --overwrite` e reinicie o deployment
(`kubectl -n toggle-master rollout restart deployment/evaluation-service`).

## 10. Roteiro sugerido para o vídeo de demonstração

1. `terraform plan` / `terraform apply` (ou mostrar os recursos já criados no console AWS)
2. Editar um dos serviços introduzindo uma dependência vulnerável (ex: `Flask==0.12` em
   `flag-service/requirements.txt`) → abrir PR → mostrar o job `security-scan` falhando
3. Reverter a alteração → mostrar o pipeline passando e o job `docker-build-push` publicando no ECR
4. Mostrar o commit automático no repositório `togglemaster-gitops` (job `update-gitops`)
5. Abrir a UI do ArgoCD e mostrar a sincronização automática da nova versão

## Custos (para o print pedido no relatório)

Use o [AWS Pricing Calculator](https://calculator.aws) ou o Cost Explorer depois de
alguns dias de uso. Os maiores custos aqui são: EKS control plane (~US$0,10/h fixo),
NAT Gateway (~US$0,045/h + tráfego), e os nodes EC2 do node group — todo o resto
(RDS/Redis `t4g.micro`, DynamoDB on-demand, SQS, ECR) é próximo de gratuito em
volume de laboratório.

## Limpeza (evitar custo residual)

```bash
kubectl delete -f gitops/argocd-applications/   # remove as Applications (não apaga os recursos AWS)
cd terraform && terraform destroy
cd bootstrap && terraform destroy   # só depois de mover/descartar o state
```
