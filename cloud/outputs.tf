output "aws_lambda_name" {
  description = "The name of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_name : null
}

output "aws_lambda_aes_key" {
  description = "The AES key used by the AWS Lambda function for encryption, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].generated_aes_key : null
  sensitive   = true
}

output "generated_ssh_public_key" {
  value = length(module.google) > 0 ? module.google[0].generated_ssh_public_key : null
}

output "generated_ssh_private_key" {
  value     = length(module.google) > 0 ? module.google[0].generated_ssh_private_key : null
  sensitive = true
}

output "vm_ip_address" {
  value = length(module.google) > 0 ? module.google[0].vm_ip_address : null
}

output "vm_fqdn" {
  value = length(module.google) > 0 ? module.google[0].vm_fqdn : null
}

output "aws_lambda_url" {
  description = "The URL of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_url : null
}

output "https_proxy_cert" {
  value       = length(module.google) > 0 ? module.google[0].https_proxy_cert : null
  description = "The self-signed certificate used by the HTTPS proxy (only if no domain provided)"
}

output "vm_instance_name" {
  value = length(module.google) > 0 ? module.google[0].vm_instance_name : null
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value       = length(module.google) > 0 ? module.google[0].wireguard : null
}

output "ipsec_vpn" {
  description = "IPSec/L2TP VPN configuration and status"
  value       = length(module.google) > 0 ? module.google[0].ipsec_vpn : null
}

output "ipsec_vpn_secrets" {
  description = "IPSec/L2TP VPN sensitive configuration values"
  value       = length(module.google) > 0 ? module.google[0].ipsec_vpn_secrets : null
  sensitive   = true
}
