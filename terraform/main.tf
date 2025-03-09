terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "local" {}
}

# AWS provider configuration to interact with Localstack
provider "aws" {
  region                      = var.region
  access_key                  = "test"  # Dummy access key for Localstack
  secret_key                  = "test"  # Dummy secret key for Localstack
  skip_credentials_validation = true  # Skip actual AWS credentials validation
  skip_requesting_account_id  = true  # Skip account ID validation
  skip_metadata_api_check     = true

  endpoints {
    apigateway = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    iam        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    s3         = "http://localhost:4566"
  }
}

# Module for DynamoDB resources
module "dynamodb" {
  source = "./modules/dynamodb"
  dynamodb_table_name = var.dynamodb_table_name
}

# Module for Lambda function configuration
module "lambda" {
  source               = "./modules/lambda"
  region               = var.region
  dynamodb_table_name  = var.dynamodb_table_name
  lambda_function_name = var.lambda_function_name
}

# Module for API Gateway configuration
module "api_gateway" {
  source               = "./modules/api_gateway"
  region               = var.region
  api_stage            = var.api_stage
  lambda_function_arn  = module.lambda.lambda_function_arn
  lambda_function_name = var.lambda_function_name
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
}

output "api_gateway_outputs" {
  value = module.api_gateway
}
