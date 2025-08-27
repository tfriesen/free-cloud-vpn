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
    ipsec_vpn        = module.google[0].ipsec_vpn
    fqdn             = module.google[0].vm_fqdn
    ssh_public_key   = module.google[0].generated_ssh_public_key
    https_proxy      = module.google[0].https_proxy
  } : null
}

# Google Cloud VM sensitive outputs
output "google_vm_secrets" {
  description = "Google Cloud VM sensitive credentials and keys"
  value = length(module.google) > 0 ? {
    ipsec_vpn_secrets   = module.google[0].ipsec_vpn_secrets
    ssh_private_key     = module.google[0].generated_ssh_private_key
    pingtunnel_key      = module.google[0].pingtunnel_key
    pingtunnel_aes_key  = module.google[0].pingtunnel_aes_key
    wireguard           = module.google[0].wireguard
    https_proxy_secrets = module.google[0].https_proxy_secrets
  } : null
  sensitive = true
}

# Oracle Cloud VM outputs (non-sensitive)
output "oracle_vm" {
  description = "Oracle Cloud VM non-sensitive details"
  value = length(module.oracle) > 0 ? {
    ip_address     = module.oracle[0].vm_ip_address
    ipv6_address   = module.oracle[0].vm_ipv6_address
    ipsec_vpn      = module.oracle[0].ipsec_vpn
    fqdn           = module.oracle[0].vm_fqdn
    instance_id    = module.oracle[0].instance_id
    ssh_public_key = module.oracle[0].generated_ssh_public_key
    https_proxy    = module.oracle[0].https_proxy
  } : null
}

# Oracle Cloud VM sensitive outputs
output "oracle_vm_secrets" {
  description = "Oracle Cloud VM sensitive credentials and keys"
  value = length(module.oracle) > 0 ? {
    ipsec_vpn_secrets   = module.oracle[0].ipsec_vpn_secrets
    ssh_private_key     = module.oracle[0].generated_ssh_private_key
    pingtunnel_key      = module.oracle[0].pingtunnel_key
    pingtunnel_aes_key  = module.oracle[0].pingtunnel_aes_key
    wireguard           = module.oracle[0].wireguard
    https_proxy_secrets = module.oracle[0].https_proxy_secrets
  } : null
  sensitive = true
}

output "aws_lambda_url" {
  description = "The URL of the AWS Lambda function, if AWS is enabled"
  value       = length(module.aws) > 0 ? module.aws[0].lambda_function_url : null
}

# Cloudflare outputs
output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the specified domain"
  value       = length(module.cloudflare) > 0 ? module.cloudflare[0].zone_id : null
}

output "cloudflare_origin_certificate_pem" {
  description = "Cloudflare Origin CA certificate (PEM)"
  value       = length(module.cloudflare) > 0 ? module.cloudflare[0].origin_certificate_pem : null
}
