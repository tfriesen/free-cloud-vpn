resource "aws_lambda_function" "basic_lambda" {
  function_name    = "basic_lambda"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 900
  layers           = [aws_lambda_layer_version.requests_layer.arn]
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.basic_lambda.function_name
  authorization_type = "NONE"
}

# Generate a random AES key and store in AWS Secrets Manager
resource "random_password" "aes_key" {
  length  = 32
  special = false
}

# Lambda Layer for dependencies (requests library)
resource "aws_lambda_layer_version" "requests_layer" {
  layer_name          = "requests_layer"
  filename            = "${path.module}/requests_layer.zip"
  compatible_runtimes = ["python3.12"]
  description         = "Layer containing third-party Python dependencies such as requests. Build requests_layer.zip by running build_layer.sh in this module."
}
