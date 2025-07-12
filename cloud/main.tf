module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0
}

module "aws" {
  source = "./modules/aws"
  count  = var.enable_aws ? 1 : 0
}

module "google" {
  source = "./modules/google"
  count  = var.enable_google ? 1 : 0
}
