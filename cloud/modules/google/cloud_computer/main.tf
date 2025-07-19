locals {
  effective_ssh_key = var.ssh_keys != "" ? var.ssh_keys : "${chomp(tls_private_key.generated_key[0].public_key_openssh)} ${var.vm_username}"
  effective_dns_password = var.dns_tunnel_password != "" ? var.dns_tunnel_password : (
    var.enable_dns_tunnel ? random_password.dns_tunnel[0].result : ""
  )
  effective_proxy_password = var.https_proxy_password != "" ? var.https_proxy_password : random_password.proxy[0].result
  has_proxy_domain         = var.https_proxy_domain != ""
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

  dynamic "allow" {
    for_each = var.enable_icmp_tunnel ? [1] : []
    content {
      protocol = "icmp"
    }
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

resource "random_password" "proxy" {
  count   = var.https_proxy_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "tls_private_key" "proxy_cert" {
  count     = local.has_proxy_domain ? 0 : 1
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "proxy_cert" {
  count           = local.has_proxy_domain ? 0 : 1
  private_key_pem = tls_private_key.proxy_cert[0].private_key_pem

  subject {
    common_name  = "acme.local"
    organization = "Acme, Inc."
  }

  validity_period_hours = 87600
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
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
    
    # Custom pre-configuration commands
    %{if var.custom_pre_config != ""}
    # User-provided pre-configuration
    ${var.custom_pre_config}
    %{endif}
    
    # Update package lists
    apt-get update
    
    # Install required packages non-interactively
    DEBIAN_FRONTEND=noninteractive apt-get install -y htop netcat tinyproxy apache2-utils stunnel4

    %{if var.enable_icmp_tunnel}
    # Install build dependencies for ICMP tunnel
    DEBIAN_FRONTEND=noninteractive apt-get install -y git build-essential
    
    # Install and configure icmptunnel
    if [ ! -d "/opt/icmptunnel" ]; then
      git clone https://github.com/jamesbarlow/icmptunnel.git /opt/icmptunnel
      cd /opt/icmptunnel
      make
    fi

    # Create icmptunnel systemd service
    cat > /etc/systemd/system/icmptunnel.service << 'ICMPSERVICE'
    [Unit]
    Description=ICMP Tunnel Server
    After=network.target

    [Service]
    Type=simple
    ExecStart=/opt/icmptunnel/icmptunnel -s -d
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    ICMPSERVICE

    # Create network interface configuration
    cat > /etc/systemd/network/99-icmptunnel.network << 'ICMPNETWORK'
    [Match]
    Name=tun0

    [Network]
    Address=172.31.8.1/24
    ICMPNETWORK

    systemctl daemon-reload
    systemctl enable systemd-networkd
    systemctl enable icmptunnel
    systemctl restart icmptunnel
    systemctl restart systemd-networkd
    %{endif}

  
    # Configure tinyproxy to listen only on localhost
    cat > /etc/tinyproxy/tinyproxy.conf << 'TINYPROXYCONF'
    User tinyproxy
    Group tinyproxy
    Port 8888
    Listen 127.0.0.1
    Timeout 600
    DefaultErrorFile "/usr/share/tinyproxy/default.html"
    StatFile "/usr/share/tinyproxy/stats.html"
    LogFile "/var/log/tinyproxy/tinyproxy.log"
    LogLevel Info
    PidFile "/run/tinyproxy/tinyproxy.pid"
    MaxClients 100
    MinSpareServers 5
    MaxSpareServers 20
    StartServers 10
    MaxRequestsPerChild 0
    Allow 127.0.0.1
    ViaProxyName "tinyproxy"
    BasicAuth clouduser ${local.effective_proxy_password}
    TINYPROXYCONF

    # Create SSL directory
    mkdir -p /etc/stunnel/ssl
    %{if local.has_proxy_domain}
    # Install certbot for LetsEncrypt
    DEBIAN_FRONTEND=noninteractive apt-get install -y certbot

    # Get LetsEncrypt certificate
    certbot certonly --standalone --non-interactive --agree-tos --email admin@${var.https_proxy_domain} -d ${var.https_proxy_domain}
    
    # Link certificates
    ln -sf /etc/letsencrypt/live/${var.https_proxy_domain}/fullchain.pem /etc/stunnel/ssl/cert.pem
    ln -sf /etc/letsencrypt/live/${var.https_proxy_domain}/privkey.pem /etc/stunnel/ssl/key.pem

    # Setup cert renewal hook
    cat > /etc/letsencrypt/renewal-hooks/deploy/stunnel << 'RENEWHOOK'
    #!/bin/bash
    systemctl restart stunnel4
    RENEWHOOK
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/stunnel
    %{else}
    # Use self-signed certificate
    cat > /etc/stunnel/ssl/cert.pem << 'CERT'
    ${tls_self_signed_cert.proxy_cert[0].cert_pem}
    CERT
    
    cat > /etc/stunnel/ssl/key.pem << 'KEY'
    ${tls_private_key.proxy_cert[0].private_key_pem}
    KEY
    %{endif}

    # Configure stunnel
    cat > /etc/stunnel/stunnel.conf << 'STUNNELCONF'
    foreground = no
    pid = /var/run/stunnel4/stunnel.pid
    
    [https]
    accept = 443
    connect = 127.0.0.1:8888
    cert = /etc/stunnel/ssl/cert.pem
    key = /etc/stunnel/ssl/key.pem
    TIMEOUTclose = 0
    options = NO_SSLv2
    options = NO_SSLv3
    #PFE, 256 bits or better, SHA256 or better
    ciphers = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384
    #TLS1.3 specific ciphers
    ciphersuites = TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384
    sslVersionMin = TLSv1.2
    STUNNELCONF

    chmod 600 /etc/stunnel/ssl/*
    chmod 600 /etc/stunnel/stunnel.conf

    # Enable and start services
    systemctl enable stunnel4
    systemctl enable tinyproxy
    systemctl restart tinyproxy
    systemctl restart stunnel4

    # Configure SSH to also listen on port 80 (after certbot is done)
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

    %{if var.custom_post_config != ""}
    # User-provided post-configuration
    ${var.custom_post_config}
    %{endif}
  EOF

  metadata = {
    ssh-keys = "${var.vm_username}:${local.effective_ssh_key}"
  }
}

