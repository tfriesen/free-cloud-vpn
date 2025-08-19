#!/bin/bash

#set some env vars useful for the user scripts
cloud_provider="${cloud_provider}"
arch="${arch}"

# Custom pre-configuration commands
%{if custom_pre_config != ""}
# User-provided pre-configuration
${custom_pre_config}
%{endif}

#Flush forward rules, as some providers muck with the defaults
iptables -F FORWARD
iptables -A FORWARD -j ACCEPT

# Update package lists
DEBIAN_FRONTEND=noninteractive apt-get update -o DPkg::Timeout::=10

# Install required packages non-interactively
DEBIAN_FRONTEND=noninteractive apt-get install -y htop netcat-traditional

# Provider-specific startup steps
%{if cloud_provider == "google"}
${templatefile("${path}/templates/google-provider-setup.sh.tpl", {})}
%{endif}

%{if cloud_provider == "oracle"}
${templatefile("${path}/templates/oracle-provider-setup.sh.tpl", {})}
%{endif}

# Include feature-specific configurations
%{if wireguard_enabled}
#We do wireguard first so as to get the wireguard public key into the guest attributes ASAP
${templatefile("${path}/templates/wireguard-setup.sh.tpl", {
  wireguard_private_key = wireguard_private_key,
  vm_guest_attr_namespace = vm_guest_attr_namespace,
  wg_pubkey_attr_key = wg_pubkey_attr_key,
  wireguard_server_ip = wireguard_server_ip,
  wireguard_config = wireguard_config
  cloud_provider = cloud_provider
})}
%{endif}

%{if pingtunnel_enabled}
${templatefile("${path}/templates/pingtunnel-setup.sh.tpl", {
  pingtunnel_key = pingtunnel_key
  pingtunnel_aes_key = pingtunnel_aes_key
  arch = arch
})}
%{endif}

${templatefile("${path}/templates/proxy-setup.sh.tpl", {
  effective_proxy_password = effective_proxy_password,
  has_proxy_domain = has_proxy_domain,
  https_proxy_domain = https_proxy_domain,
  tls_self_signed_cert_proxy = tls_self_signed_cert_proxy,
  tls_private_key_proxy_cert = tls_private_key_proxy_cert
})}

# Configure SSH to listen on multiple ports
# Remove any existing Port directives to avoid conflicts
sed -i '/^Port /d' /etc/ssh/sshd_config

# Add the configured SSH ports
%{for port in ssh_ports ~}
echo "Port ${port}" >> /etc/ssh/sshd_config
iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
%{endfor}

# Restart SSH service to apply new configuration
systemctl daemon-reload
systemctl restart ssh.socket
systemctl restart ssh

%{if dns_tunnel_enabled}
${templatefile("${path}/templates/dns-tunnel-setup.sh.tpl", {
  effective_dns_password = effective_dns_password,
  dns_tunnel_config = dns_tunnel_config
})}
%{endif}

%{if ipsec_vpn_enabled}
${templatefile("${path}/templates/ipsec-vpn-setup.sh.tpl", {
  vpn_client_ip_start = vpn_client_ip_start,
  vpn_client_ip_end = vpn_client_ip_end,
  vpn_server_ip = vpn_server_ip,
  effective_vpn_username = effective_vpn_username,
  effective_vpn_password = effective_vpn_password,
  effective_ipsec_psk = effective_ipsec_psk
})}
%{endif}

%{if custom_post_config != ""}
# User-provided post-configuration
${custom_post_config}
%{endif} 
