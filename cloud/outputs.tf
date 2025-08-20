output "aws_lambda_name" {
  description = "The name of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_name : null
}

output "aws_lambda_aes_key" {
  description = "The AES key used by the AWS Lambda function for encryption, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].generated_aes_key : null
  sensitive   = true
}

# Google Cloud VM outputs (non-sensitive)
output "google_vm" {
  description = "Google Cloud VM non-sensitive details"
  value = length(module.google) > 0 ? {
    vm_instance_name = module.google[0].vm_instance_name
    ip_address       = module.google[0].vm_ip_address
    fqdn             = module.google[0].vm_fqdn
    ssh_public_key   = module.google[0].generated_ssh_public_key
    https_proxy_cert = module.google[0].https_proxy_cert
  } : null
}

# Google Cloud VM sensitive outputs
output "google_vm_secrets" {
  description = "Google Cloud VM sensitive credentials and keys"
  value = length(module.google) > 0 ? {
    ssh_private_key    = module.google[0].generated_ssh_private_key
    pingtunnel_key     = module.google[0].pingtunnel_key
    pingtunnel_aes_key = module.google[0].pingtunnel_aes_key
    wireguard          = module.google[0].wireguard
  } : null
  sensitive = true
}

# Oracle Cloud VM outputs (non-sensitive)
output "oracle_vm" {
  description = "Oracle Cloud VM non-sensitive details"
  value = length(module.oracle) > 0 ? {
    ip_address       = module.oracle[0].vm_ip_address
    ipv6_address     = module.oracle[0].vm_ipv6_address
    fqdn             = module.oracle[0].vm_fqdn
    instance_id      = module.oracle[0].instance_id
    ssh_public_key   = module.oracle[0].generated_ssh_public_key
    https_proxy_cert = module.oracle[0].https_proxy_cert
  } : null
}

# Oracle Cloud VM sensitive outputs
output "oracle_vm_secrets" {
  description = "Oracle Cloud VM sensitive credentials and keys"
  value = length(module.oracle) > 0 ? {
    ssh_private_key    = module.oracle[0].generated_ssh_private_key
    pingtunnel_key     = module.oracle[0].pingtunnel_key
    pingtunnel_aes_key = module.oracle[0].pingtunnel_aes_key
    wireguard          = module.oracle[0].wireguard
  } : null
  sensitive = true
}

output "aws_lambda_url" {
  description = "The URL of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_url : null
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value       = length(module.google) > 0 && var.wireguard_config.enable ? module.google[0].wireguard : null
}

output "ipsec_vpn" {
  description = "IPSec/IKEv2 VPN configuration and status"
  value       = length(module.google) > 0 && var.ipsec_vpn_config.enable ? module.google[0].ipsec_vpn : null
}

output "ipsec_vpn_secrets" {
  description = "IPSec/IKEv2 VPN sensitive configuration values"
  value       = length(module.google) > 0 ? module.google[0].ipsec_vpn_secrets : null
  sensitive   = true
}
