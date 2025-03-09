variable "region" {
  description = "The AWS region where the resources are deployed"
  type        = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

# This resource creates the Lambda package (ZIP file) dynamically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda/lambda_function.py"
  output_path = "lambda/lambda_function.zip"
}

# This resource deploys the Lambda function, depending on the ZIP file
resource "aws_lambda_function" "entry_function" {

  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.8"  
  s3_bucket     = "hot-reload"
  s3_key        = "${path.cwd}/lambda"
  
  # Ensure the Lambda function updates when the ZIP file changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

// Create the execution IAM role for our lambda function
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Output the ARN of the Lambda function
output "lambda_function_arn" {
  value = aws_lambda_function.entry_function.arn
}

output "lambda_invoke_arn" {
  value = aws_lambda_function.entry_function.invoke_arn
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy"
  description = "Allow Lambda to interact with DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${var.region}:*:table/${var.dynamodb_table_name}"
      }
    ]
  })
}
