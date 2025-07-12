resource "aws_lambda_function" "basic_lambda" {
  function_name     = "basic_lambda"
  handler           = "lambda_function.lambda_handler"
  runtime           = "python3.12"
  role              = aws_iam_role.lambda_exec.arn
  filename          = "${path.module}/lambda_function.py"
  source_code_hash  = filebase64sha256("${path.module}/lambda_function.py")
  architectures     = ["arm64"]
  memory_size       = 128
  timeout           = 900
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

resource "aws_iam_policy" "lambda_secrets_policy" {
  name        = "lambda-secrets-policy"
  description = "Allow Lambda to read AES key from Secrets Manager"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = aws_secretsmanager_secret.lambda_aes_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
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

resource "aws_secretsmanager_secret" "lambda_aes_key" {
  name = "lambda-aes-key"
}

resource "aws_secretsmanager_secret_version" "lambda_aes_key_version" {
  secret_id     = aws_secretsmanager_secret.lambda_aes_key.id
  secret_string = random_password.aes_key.result
}
