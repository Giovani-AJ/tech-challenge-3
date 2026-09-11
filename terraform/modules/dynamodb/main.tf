## Tabela DynamoDB usada pelo analytics-service (event_id como partition key,
## igual ao item montado em analytics-service/app.py).

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }
}
