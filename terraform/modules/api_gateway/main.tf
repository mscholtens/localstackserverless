# Define a variable to receive the Lambda ARN from the parent module
variable "region" {
  description = "The AWS region where the resources are deployed"
  type        = string
}

variable "api_stage" {
  description = "The api stage"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

# Define API Gateway resources, methods, and integrations for each endpoint
resource "aws_api_gateway_rest_api" "api" {
  name        = "serverless-api"
  description = "API for CRUD operations on entries"
}

resource "aws_api_gateway_resource" "entries_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "entry"
}

resource "aws_api_gateway_resource" "entries_list_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "entries"
}

resource "aws_api_gateway_method" "entry_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.entries_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "entry_integration_post" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.entries_resource.id
  http_method          = aws_api_gateway_method.entry_method_post.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

resource "aws_api_gateway_method" "entry_method_put" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.entries_resource.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "entry_integration_put" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.entries_resource.id
  http_method          = aws_api_gateway_method.entry_method_put.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

# GET: Find an entry by date and workflow (using non-proxy integration)
resource "aws_api_gateway_method" "entry_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.entries_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "entry_integration_get" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.entries_resource.id
  http_method          = aws_api_gateway_method.entry_method_get.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

# DELETE: Delete an entry by date and workflow (using non-proxy integration)
resource "aws_api_gateway_method" "entry_method_delete" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.entries_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "entry_integration_delete" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.entries_resource.id
  http_method          = aws_api_gateway_method.entry_method_delete.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

# GET: List all entries (using non-proxy integration)
resource "aws_api_gateway_method" "entry_method_list" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.entries_list_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.limit" = false
    "method.request.querystring.page"  = false
  }
}

resource "aws_api_gateway_integration" "entry_integration_list" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.entries_list_resource.id
  http_method          = aws_api_gateway_method.entry_method_list.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = var.lambda_invoke_arn
}

# Enable API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.api_stage}/*"
}

# Define the API Gateway deployment stage
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.entry_integration_post,
    aws_api_gateway_integration.entry_integration_put,
    aws_api_gateway_integration.entry_integration_get,
    aws_api_gateway_integration.entry_integration_delete,
    aws_api_gateway_integration.entry_integration_list
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_stage

  lifecycle {
    create_before_destroy = true
  }
}

# Define the API Gateway URL for use
output "entry_api_gateway_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/entry"
  depends_on = [aws_api_gateway_deployment.api_deployment]
}

output "entries_api_gateway_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/entries"
  depends_on = [aws_api_gateway_deployment.api_deployment]
}

output "source_arn" {
  value = "${aws_lambda_permission.allow_apigateway.source_arn}"
  depends_on = [aws_api_gateway_deployment.api_deployment]
}

output "invoke_arn" {
  value = var.lambda_invoke_arn
  depends_on = [aws_api_gateway_deployment.api_deployment]
}
