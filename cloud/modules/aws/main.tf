module "lambda" {
  source      = "./lambda"
  alert_email = var.alert_email
}
