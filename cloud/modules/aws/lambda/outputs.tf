output "lambda_function_name" {
  value = aws_lambda_function.basic_lambda.function_name
}

output "generated_aes_key" {
  value     = random_password.aes_key.result
  sensitive = true
}

output "lambda_function_url" {
  value = aws_lambda_function_url.lambda_url.function_url
}
