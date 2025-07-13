output "lambda_function_url" {
  description = "The URL of the Lambda function"
  value       = module.lambda.lambda_function_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = module.lambda.lambda_function_name
}

output "generated_aes_key" {
  description = "The generated AES key used by the Lambda function"
  value       = module.lambda.generated_aes_key
  sensitive   = true
}
