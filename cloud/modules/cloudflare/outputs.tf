output "zone_id" {
  description = "Cloudflare Zone ID for the specified domain"
  value       = data.cloudflare_zones.this.result[0].id
}

output "origin_certificate_pem" {
  description = "Cloudflare Origin CA certificate (PEM)"
  value       = try(cloudflare_origin_ca_certificate.origin[0].certificate, null)
}

output "origin_private_key_pem" {
  description = "Cloudflare Origin CA private key (PEM)"
  value       = try(tls_private_key.origin[0].private_key_pem, null)
  sensitive   = true
}
