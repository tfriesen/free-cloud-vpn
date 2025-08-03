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
    ssh_private_key = module.google[0].generated_ssh_private_key
    pingtunnel_key  = module.google[0].pingtunnel_key
    wireguard       = module.google[0].wireguard
  } : null
  sensitive = true
}

# Oracle Cloud VM outputs (non-sensitive)
output "oracle_vm" {
  description = "Oracle Cloud VM non-sensitive details"
  value = length(module.oracle) > 0 ? {
    ip_address       = module.oracle[0].vm_ip_address
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
    ssh_private_key = module.oracle[0].generated_ssh_private_key
    pingtunnel_key  = module.oracle[0].pingtunnel_key
    wireguard       = module.oracle[0].wireguard
  } : null
  sensitive = true
}

# Individual outputs (deprecated, use google_vm/google_vm_secrets or oracle_vm/oracle_vm_secrets objects instead)
output "generated_ssh_public_key" {
  value       = length(module.google) > 0 ? module.google[0].generated_ssh_public_key : null
  description = "[DEPRECATED] Use google_vm.ssh_public_key or oracle_vm.ssh_public_key instead"
}

output "generated_ssh_private_key" {
  value       = length(module.google) > 0 ? module.google[0].generated_ssh_private_key : null
  sensitive   = true
  description = "[DEPRECATED] Use google_vm.ssh_private_key or oracle_vm.ssh_private_key instead"
}

output "vm_ip_address" {
  value       = length(module.google) > 0 ? module.google[0].vm_ip_address : null
  description = "[DEPRECATED] Use google_vm.ip_address or oracle_vm.ip_address instead"
}

output "vm_fqdn" {
  value       = length(module.google) > 0 ? module.google[0].vm_fqdn : null
  description = "[DEPRECATED] Use google_vm.fqdn or oracle_vm.fqdn instead"
}

output "aws_lambda_url" {
  description = "The URL of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_url : null
}

output "pingtunnel_key" {
  description = "[DEPRECATED] Use google_vm.pingtunnel_key or oracle_vm.pingtunnel_key instead"
  value       = length(module.google) > 0 ? module.google[0].pingtunnel_key : null
  sensitive   = true
}

output "dns_tunnel_password" {
  description = "[DEPRECATED] Use google_vm.dns_tunnel_password or oracle_vm.dns_tunnel_password instead"
  value       = length(module.google) > 0 ? module.google[0].dns_tunnel_password : null
  sensitive   = true
}

output "https_proxy_cert" {
  value       = length(module.google) > 0 ? module.google[0].https_proxy_cert : null
  description = "[DEPRECATED] Use google_vm.https_proxy_cert or oracle_vm.https_proxy_cert instead"
}

output "vm_instance_name" {
  value = length(module.google) > 0 ? module.google[0].vm_instance_name : null
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
