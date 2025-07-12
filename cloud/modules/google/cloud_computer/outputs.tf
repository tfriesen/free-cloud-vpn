output "instance_name" {
  value = google_compute_instance.free_tier_vm.name
}

output "generated_ssh_public_key" {
  value = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].public_key_openssh
}

output "generated_ssh_private_key" {
  value = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].private_key_openssh
  sensitive = true
}

output "vm_ip_address" {
  value = google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip
}

