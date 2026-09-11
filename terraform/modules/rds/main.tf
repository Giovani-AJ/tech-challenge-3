## Uma instância RDS PostgreSQL + Security Group + senha aleatória guardada no
## Secrets Manager (nunca em texto plano em nenhum arquivo do repositório).
## Instanciado 3x na raiz (auth, flag, targeting).

## Sem caracteres especiais de propósito: a senha vai direto para dentro de uma
## DATABASE_URL (postgres://user:senha@host/db) sem URL-encoding, então qualquer
## caractere reservado de URI (%, $, @, /, & etc.) quebraria o parsing do psql/driver.
## "-" e "_" são os únicos especiais "unreserved" em URI (RFC 3986) e continuam liberados.
resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "-_"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Permite acesso Postgres a partir do cluster EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres a partir dos nodes EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.identifier}-sg"
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  tags = {
    Name    = var.identifier
    Service = var.service_name
  }
}

# Segredo consumido pelo External Secrets Operator -> vira K8s Secret no namespace da app.
resource "aws_secretsmanager_secret" "db" {
  name = "${var.secret_prefix}/${var.identifier}"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    DB_USER      = var.master_username
    DB_PASSWORD  = random_password.master.result
    DB_HOST      = aws_db_instance.this.address
    DB_PORT      = tostring(aws_db_instance.this.port)
    DB_NAME      = var.db_name
    DATABASE_URL = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}"
  })
}
