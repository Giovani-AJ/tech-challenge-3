# ==========================================
# ESTÁGIO 1: Builder (Compilação com Cache)
# ==========================================
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 1. Copia apenas o arquivo de pacotes para o cache do Docker
COPY go.mod ./

# 2. Baixa as dependências e joga no cache
RUN go mod download

# 3. Copia o restante do código fonte
COPY . .

# 4. Compila (os imports não usados foram corrigidos direto no código-fonte)
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o meu-app .

# ==========================================
# ESTÁGIO 2: Imagem Final de Produção
# ==========================================
FROM alpine:3.19 AS prod

WORKDIR /app

# Copia apenas o executável perfeito e limpo
COPY --from=builder /app/meu-app ./meu-app

EXPOSE 8001

CMD ["./meu-app"]