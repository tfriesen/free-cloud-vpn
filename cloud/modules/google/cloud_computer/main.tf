locals {
  effective_ssh_key = var.ssh_keys != "" ? var.ssh_keys : "${chomp(tls_private_key.generated_key[0].public_key_openssh)} ${var.vm_username}"
  effective_dns_password = var.dns_tunnel_password != "" ? var.dns_tunnel_password : (
    var.enable_dns_tunnel ? random_password.dns_tunnel[0].result : ""
  )
  effective_proxy_password = var.https_proxy_password != "" ? var.https_proxy_password : random_password.proxy[0].result
  has_proxy_domain         = var.https_proxy_domain != ""
  effective_vpn_username   = var.vpn_username != "" ? var.vpn_username : var.vm_username
  effective_vpn_password = var.vpn_password != "" ? var.vpn_password : (
    var.enable_ipsec_vpn ? random_password.vpn[0].result : ""
  )
  effective_ipsec_psk = var.ipsec_psk != "" ? var.ipsec_psk : (
    var.enable_ipsec_vpn ? random_password.ipsec_psk[0].result : ""
  )
  vpn_client_network    = split("/", var.vpn_client_ip_pool)[0]
  vpn_client_netmask    = cidrnetmask(var.vpn_client_ip_pool)
  vpn_server_ip         = cidrhost(var.vpn_client_ip_pool, 1)
  vpn_client_ip_start   = cidrhost(var.vpn_client_ip_pool, 100)
  vpn_client_ip_end     = cidrhost(var.vpn_client_ip_pool, 200)
  wireguard_server_ip   = replace(var.wireguard_config.client_ip, "2/24", "1/24") # Replace last octet with 1
  wireguard_private_key = var.wireguard_config.enable ? tls_private_key.wireguard[0].private_key_pem : ""

  vm_guest_attr_namespace = "free-tier-vm-guestattr-namespace"
  wg_pubkey_attr_key      = "wireguard-public-key"
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
    ports = concat(
      ["53", "500", "4500"],
      var.wireguard_config.enable ? [var.wireguard_config.port] : []
    )
  }

  dynamic "allow" {
    for_each = var.enable_icmp_tunnel ? [1] : []
    content {
      protocol = "icmp"
    }
  }

  dynamic "allow" {
    for_each = var.enable_ipsec_vpn ? [1] : []
    content {
      protocol = "esp"
    }
  }

  dynamic "allow" {
    for_each = var.enable_ipsec_vpn ? [1] : []
    content {
      protocol = "ah"
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

resource "random_password" "vpn" {
  count   = var.enable_ipsec_vpn && var.vpn_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "ipsec_psk" {
  count   = var.enable_ipsec_vpn && var.ipsec_psk == "" ? 1 : 0
  length  = 32
  special = false
}

resource "tls_private_key" "wireguard" {
  count     = var.wireguard_config.enable ? 1 : 0
  algorithm = "ED25519"
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

# Create a service account for the VM
resource "google_service_account" "vm_service_account" {
  account_id   = "free-tier-vm-sa"
  display_name = "Service Account for Free Tier VM"
  description  = "Minimal service account for the free tier VM instance"
}

# Grant minimal required permissions
resource "google_project_iam_member" "instance_log_writer" {
  project = google_compute_instance.free_tier_vm.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "instance_metric_writer" {
  project = google_compute_instance.free_tier_vm.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
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

  # Use the custom service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

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
    DEBIAN_FRONTEND=noninteractive apt-get install -y htop netcat tinyproxy apache2-utils stunnel4 libreswan xl2tpd


    #We do wireguard first so that the public key is available for the guest attributes ASAP
    %{if var.wireguard_config.enable}
    # Install WireGuard
    DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard

    # Convert private key from PEM to wg format.
    echo "${local.wireguard_private_key}" | openssl pkey -in - -outform DER -out private_key.der && dd if=private_key.der bs=1 skip=$(($(stat -c %s private_key.der) - 32)) count=32 2>/dev/null | base64 > /etc/wireguard/private.key
    wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
    chmod 600 /etc/wireguard/private.key

    curl -X PUT -H "Metadata-Flavor: Google" --data "$(cat /etc/wireguard/public.key)" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/${local.vm_guest_attr_namespace}/${local.wg_pubkey_attr_key} 

    # Create WireGuard configuration
    cat > /etc/wireguard/wg0.conf << WIREGUARDCONF
    [Interface]
    PrivateKey = $(cat /etc/wireguard/private.key)
    Address = ${local.wireguard_server_ip}
    ListenPort = ${var.wireguard_config.port}

    [Peer]
    PublicKey = ${var.wireguard_config.client_public_key}
    AllowedIPs = ${var.wireguard_config.client_ip}

    WIREGUARDCONF
    chmod 600 /etc/wireguard/wg0.conf

    # Enable IP forwarding for WireGuard
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf

    #Firewall rules for forwarding. Not sure why the INPUT rule is needed, but it is.
    iptables -A INPUT -i wg0 -j ACCEPT
    iptables -t nat -A POSTROUTING -o $(ls /sys/class/net/ | grep ens) -j MASQUERADE

    # Enable and start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    %{endif}


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


    %{if var.enable_ipsec_vpn}
    # Configure IPSec/L2TP VPN
    cat > /etc/ipsec.conf << 'IPSECCONF'
    config setup
        virtual-private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
        protostack=netkey
        uniqueids=no

    conn L2TP-PSK-NAT
        rightsubnet=vhost:%priv
        also=L2TP-PSK-noNAT

    conn L2TP-PSK-noNAT
        authby=secret
        pfs=no
        auto=add
        keyingtries=3
        rekey=no
        ikelifetime=8h
        keylife=1h
        type=transport
        left=%defaultroute
        leftid=%defaultroute
        leftprotoport=17/1701
        right=%any
        rightprotoport=17/%any
        dpddelay=30
        dpdtimeout=120
        dpdaction=clear
        encapsulation=yes
    IPSECCONF

    # Configure IPSec secrets
    cat > /etc/ipsec.secrets << IPSECSECRETS
    %defaultroute : PSK "${local.effective_ipsec_psk}"
    IPSECSECRETS
    chmod 600 /etc/ipsec.secrets

    # Configure xl2tpd
    cat > /etc/xl2tpd/xl2tpd.conf << XL2TPDCONF
    [global]
    ipsec saref = yes
    saref refinfo = 30

    [lns default]
    ip range = ${local.vpn_client_ip_start}-${local.vpn_client_ip_end}
    local ip = ${local.vpn_server_ip}
    require chap = yes
    refuse pap = yes
    require authentication = yes
    name = l2tpd
    pppoptfile = /etc/ppp/options.xl2tpd
    length bit = yes
    XL2TPDCONF

    # Configure PPP options
    cat > /etc/ppp/options.xl2tpd << PPPOPTIONS
    ipcp-accept-local
    ipcp-accept-remote
    require-mschap-v2
    ms-dns 8.8.8.8
    ms-dns 8.8.4.4
    noccp
    auth
    mtu 1400
    mru 1400
    proxyarp
    lcp-echo-failure 4
    lcp-echo-interval 30
    connect-delay 5000
    name l2tpd
    PPPOPTIONS

    # Add VPN user
    cat > /etc/ppp/chap-secrets << CHAPSECRETS
    ${local.effective_vpn_username} l2tpd "${local.effective_vpn_password}" *
    CHAPSECRETS
    chmod 600 /etc/ppp/chap-secrets

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
    echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
    sysctl -p /etc/sysctl.d/60-vpn.conf

    # Restart services
    systemctl enable ipsec
    systemctl enable xl2tpd
    systemctl restart ipsec
    systemctl restart xl2tpd
    %{endif}


    %{if var.custom_post_config != ""}
    # User-provided post-configuration
    ${var.custom_post_config}
    %{endif}
  EOF

  metadata = {
    enable-guest-attributes = "true"
    ssh-keys                = "${var.vm_username}:${local.effective_ssh_key}"
  }
}

resource "time_sleep" "wait_for_instance" {
  count           = var.wireguard_config.enable ? 1 : 0
  create_duration = "30s" #minimum time for the instance to be ready
  depends_on = [
    google_compute_instance.free_tier_vm
  ]
  lifecycle {
    # Ensure this resource is recreated if the instance is replaced
    # This is necessary to ensure the guest attributes are fetched after the instance is ready
    replace_triggered_by = [
      google_compute_instance.free_tier_vm
    ]
  }
}

data "google_compute_instance_guest_attributes" "wg_public_key" {
  count        = var.wireguard_config.enable ? 1 : 0
  name         = google_compute_instance.free_tier_vm.name
  zone         = var.zone
  variable_key = "${local.vm_guest_attr_namespace}/${local.wg_pubkey_attr_key}"

  #make sure this runs after the instance is configured
  depends_on = [
    time_sleep.wait_for_instance
  ]
}
