# Relatório de Entrega — Tech Challenge Fase 3 (ToggleMaster)

> Preencher antes de exportar como PDF para a entrega.

## Participantes

- [Nome completo] — [e-mail/RA]
- ...

## Links

- Vídeo de demonstração: [link]
- Repositório (monorepo — infra, os 5 microsserviços e o GitOps num só lugar):
  https://github.com/Giovani-AJ/tech-challenge-3

## Resumo dos desafios encontrados e decisões tomadas

### Decisões de arquitetura

**External Secrets Operator + Secrets Manager em vez de Secret estático no
manifesto.** Era exatamente o problema descrito no enunciado: credenciais de banco
em arquivo de texto (base64 não é criptografia). O Terraform gera a senha de cada
RDS aleatoriamente e grava no Secrets Manager; o ESO, rodando no cluster com uma IAM
Role própria (IRSA), materializa isso como Secret do Kubernetes. Nenhuma senha passa
pela nossa mão nem fica em nenhum arquivo versionado.

**OIDC em vez de access key de longa duração**, nos dois sentidos: GitHub Actions →
AWS (pra publicar imagem no ECR) e Pod → AWS (pra evaluation/analytics falarem com
SQS/DynamoDB). Elimina qualquer chave fixa guardada em Secret do GitHub ou hardcoded
no código.

**Monorepo em vez de 7 repositórios separados.** Começamos com uma abordagem mais
"clássica" (um repositório de infra, um de GitOps, um por microsserviço — 7 no
total). Na prática isso gerou fricção real de organização e de configuração
repetida (a mesma variável/secret em 5 lugares diferentes). Consolidamos tudo num
único repositório, com o GitOps vivendo numa pasta (`gitops/`) em vez de repositório
separado — o próprio enunciado permite essa alternativa. O ArgoCD não liga pra isso
(cada `Application` aponta só pro `path:` que importa), e o CI de cada serviço só
dispara quando o código dele muda (`paths` no trigger do workflow). Como bônus,
o job final do pipeline não precisa mais de um Personal Access Token pra empurrar
pro repositório de GitOps — usa o `GITHUB_TOKEN` padrão, já que é o mesmo repo.

### Desafios técnicos reais enfrentados

Vale destacar que quase todos os itens abaixo só apareceram na hora de rodar de
verdade contra uma conta AWS e um GitHub real — não são hipotéticos:

- **Conta AWS "Free Plan"**: uma conta pessoal nova vem com um teto rígido de
  recursos (só instância EC2 elegível a Free Tier, no máximo 2 instâncias RDS
  simultâneas). Bloqueou a criação do node group (`t3.medium`) e do 3º RDS. Resolvido
  fazendo upgrade explícito da conta pro plano pago — o upgrade em si não tem custo,
  só remove o teto; o que se paga é o uso normal.
- **Versão do EKS fora de suporte**: fixamos a versão 1.30 do Kubernetes, que já não
  tinha AMI disponível pra criar node group novo (só clusters já existentes
  continuam rodando em "extended support"). Corrigido migrando pra 1.36 (a versão
  default recomendada pela própria AWS no momento).
- **`DBName` reservado no RDS**: a AWS rejeita `flag` como nome de banco Postgres
  (palavra reservada do lado do RDS, não do Postgres em si). Resolvido renomeando
  pra `flagdb`.
- **Senha do RDS gerada com caractere inválido em URI**: o Terraform gera a senha
  aleatoriamente e monta a `DATABASE_URL` diretamente; por padrão isso pode incluir
  caracteres como `%` e `$`, que quebram o parsing de uma URI de conexão sem
  URL-encoding. Corrigido restringindo o alfabeto da senha a caracteres seguros
  em URI.
- **Token do EKS expirando no meio do `apply`**: o provider Kubernetes/Helm do
  Terraform pegava um token de autenticação fixo no início do `apply`; como
  RDS/node group demoram vários minutos pra criar, o token (validade de ~15min)
  às vezes expirava antes de chegar nos recursos do Helm/Kubernetes. Corrigido
  trocando pra autenticação "exec" (gera o token sob demanda a cada chamada,
  via `aws eks get-token`).
- **Bootstrap de admin do cluster não aplicado**: depois de recriar o cluster EKS
  (pra trocar de versão), o usuário que rodou o `apply` ficou sem nenhuma permissão
  de acesso ao cluster (o "cluster creator admin" automático da AWS não é
  garantido em todo cenário). Corrigido criando explicitamente um Access Entry +
  Access Policy Association via Terraform, em vez de depender do comportamento
  implícito.
- **Repositório Helm órfão travando o provider**: um repositório Helm de um projeto
  não relacionado, cadastrado localmente na máquina, tinha um índice de cache
  corrompido — isso bloqueava qualquer operação do provider Helm do Terraform,
  mesmo pra charts sem nenhuma relação (ArgoCD, External Secrets). Resolvido
  limpando o repositório órfão do cache local do Helm.
- **`go.sum` corrompido, mascarado pelo Docker**: o `go.sum` de dois serviços em Go
  continha, por engano, o conteúdo do `go.mod` em vez dos hashes de checksum reais.
  Isso nunca deu problema porque o `Dockerfile` rodava `go mod tidy` antes de
  compilar, consertando o arquivo silenciosamente a cada build sem nunca salvar o
  conserto de volta no repositório — só apareceu quando o pipeline de CI (sem esse
  passo escondido) tentou compilar de verdade pela primeira vez.
- **Formato novo do `sub` claim do OIDC do GitHub**: o GitHub passou a incluir IDs
  numéricos imutáveis de organização/repositório no token OIDC
  (`repo:org@123/repo@456:ref:...`), além do formato clássico só com os nomes. A
  política de confiança da IAM Role precisou de um padrão de curinga mais amplo pra
  aceitar os dois formatos.
- **CVE crítica real detectada pelo Trivy**: o scan de imagem encontrou a
  CVE-2025-68121 (crítica, `crypto/tls`) embutida no runtime do Go 1.21 usado como
  imagem base dos serviços em Go. Corrigido atualizando pra `golang:1.25-alpine`.
  Esse foi o exemplo real (não simulado) do "pipeline falha em vulnerabilidade
  crítica" pedido no desafio.
- **SSRF via taint analysis (gosec) no evaluation-service**: o `gosec` sinalizou
  como SSRF as chamadas HTTP internas do evaluation-service pro flag-service e
  targeting-service, porque a URL era montada concatenando um parâmetro vindo do
  cliente. Corrigido de verdade (não só suprimido) sanitizando o valor com
  `url.PathEscape` antes de montar a URL; o `#nosec` foi usado só pra documentar,
  com justificativa, que o host de destino é fixo e não vem de entrada externa.
- **~50 violações reais de estilo (flake8)** nos três serviços em Python (linhas em
  branco faltando entre funções, `if x: y` numa linha só, espaçamento de comentário
  inline) — nunca tinham sido pegas porque não havia pipeline de lint antes.

### Trade-offs assumidos por custo/tempo de laboratório

- NAT Gateway único (não 1 por AZ) — ponto único de falha de rede de saída, mas
  reduz custo pela metade.
- Redis sem AUTH/TLS — igual ao ambiente original da Fase 2.
- Sem Ingress/ALB público — acesso aos serviços via `kubectl port-forward` na hora
  da demonstração, em vez de expor publicamente.

(Racional completo de cada decisão de arquitetura em `docs/ARQUITETURA.md`.)

## Print da estimativa de custos da AWS

> Inserir aqui a imagem/print do Cost Explorer ou AWS Pricing Calculator.
