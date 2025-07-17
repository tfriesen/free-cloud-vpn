locals {
  effective_ssh_key = var.ssh_keys != "" ? var.ssh_keys : "${chomp(tls_private_key.generated_key[0].public_key_openssh)} ${var.vm_username}"
  effective_dns_password = var.dns_tunnel_password != "" ? var.dns_tunnel_password : (
    var.enable_dns_tunnel ? random_password.dns_tunnel[0].result : ""
  )
}

resource "google_compute_firewall" "allow_inbound" {
  name    = "allow-inbound-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "53", "80", "443"]
  }
  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "tls_private_key" "generated_key" {
  count     = var.ssh_keys == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "random_password" "dns_tunnel" {
  count   = var.enable_dns_tunnel && var.dns_tunnel_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "google_compute_instance" "free_tier_vm" {
  name         = "free-tier-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  network_interface {
    network    = "default"
    stack_type = "IPV4_ONLY"
    nic_type   = "GVNIC"
    access_config {
      network_tier = var.network_tier
    }
  }

  tags = ["http-server", "https-server"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Update package lists
    apt-get update
    
    # Install required packages non-interactively
    DEBIAN_FRONTEND=noninteractive apt-get install -y htop netcat

    # Configure SSH to also listen on port 80
    if ! grep -q "Port 80" /etc/ssh/sshd_config; then
      echo "Port 22" >> /etc/ssh/sshd_config
      echo "Port 80" >> /etc/ssh/sshd_config
      systemctl restart sshd
    fi

    %{if var.enable_dns_tunnel}
    DEBIAN_FRONTEND=noninteractive apt-get install -y iodine

    # Configure iodine DNS tunnel
    cat > /etc/default/iodine << 'IODINECONF'
    # Configuration for iodine DNS tunnel
    START_IODINED="true"

    # The tunnel password
    IODINED_PASSWORD="${local.effective_dns_password}"

    # Additional options
    IODINED_ARGS="-c ${var.dns_tunnel_ip} ${var.dns_tunnel_domain}"
    IODINECONF

    chmod 600 /etc/default/iodine
    systemctl unmask iodined
    systemctl enable iodined
    systemctl restart iodined
    %{endif}
  EOF

  metadata = {
    ssh-keys = "${var.vm_username}:${local.effective_ssh_key}"
  }
}

