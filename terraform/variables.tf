variable "region" {
  description = "The AWS region where the resources are deployed"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "ServerlessFunction"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "ApplicationTestResults"
}

variable "api_stage" {
  description = "The API Gateway stage name"
  type        = string
  default     = "dev"
}
