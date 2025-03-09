variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

resource "aws_dynamodb_table" "entries" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"  # Use on-demand billing for simplicity (change if needed)
  hash_key       = "date"  # Partition key
  range_key      = "application"  # Sort key

  attribute {
    name = "date"
    type = "S"  # String type for the partition key (date)
  }

  attribute {
    name = "application"
    type = "S"  # String type for the sort key (application)
  }
}
