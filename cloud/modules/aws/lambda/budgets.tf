# AWS Budgets for Lambda Free Tier monitoring
resource "aws_budgets_budget" "lambda_invocations" {
  count        = var.alert_email != null ? 1 : 0
  name         = "lambda-free-tier-invocations"
  budget_type  = "USAGE"
  time_unit    = "MONTHLY"
  limit_amount = "1000000"
  limit_unit   = "Requests"

  cost_filter {
    name   = "UsageType"
    values = ["Request"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_budgets_budget" "lambda_compute_time" {
  count        = var.alert_email != null ? 1 : 0
  name         = "lambda-free-tier-compute"
  budget_type  = "USAGE"
  time_unit    = "MONTHLY"
  limit_amount = "400000"
  limit_unit   = "GB-Second"

  cost_filter {
    name   = "UsageType"
    values = ["GB-Second"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Cost budget to catch any charges beyond free tier
resource "aws_budgets_budget" "lambda_cost" {
  count        = var.alert_email != null ? 1 : 0
  name         = "lambda-cost"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = "1" # $1 threshold to catch any costs beyond free tier
  limit_unit   = "USD"

  cost_filter {
    name   = "Service"
    values = ["AWS Lambda"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 0
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
