#!/bin/bash

# Custom pre-configuration commands
%{if custom_pre_config != ""}
# User-provided pre-configuration
${custom_pre_config}
%{endif}

# Update package lists
apt-get update

# Install required packages non-interactively
DEBIAN_FRONTEND=noninteractive apt-get install -y htop netcat

# Include feature-specific configurations
%{if wireguard_enabled}
#We do wireguard first so as to get the wireguard public key into the guest attributes ASAP
${templatefile("${path}/templates/wireguard-setup.sh.tpl", {
  wireguard_private_key = wireguard_private_key,
  vm_guest_attr_namespace = vm_guest_attr_namespace,
  wg_pubkey_attr_key = wg_pubkey_attr_key,
  wireguard_server_ip = wireguard_server_ip,
  wireguard_config = wireguard_config
})}
%{endif}

%{if pingtunnel_enabled}
${templatefile("${path}/templates/pingtunnel-setup.sh.tpl", {
  pingtunnel_key = pingtunnel_key
})}
%{endif}

${templatefile("${path}/templates/proxy-setup.sh.tpl", {
  effective_proxy_password = effective_proxy_password,
  has_proxy_domain = has_proxy_domain,
  https_proxy_domain = https_proxy_domain,
  tls_self_signed_cert_proxy = tls_self_signed_cert_proxy,
  tls_private_key_proxy_cert = tls_private_key_proxy_cert
})}

%{if dns_tunnel_enabled}
${templatefile("${path}/templates/dns-tunnel-setup.sh.tpl", {
  effective_dns_password = effective_dns_password,
  dns_tunnel_config = dns_tunnel_config
})}
%{endif}

%{if ipsec_vpn_enabled}
${templatefile("${path}/templates/ipsec-vpn-setup.sh.tpl", {
  effective_ipsec_psk = effective_ipsec_psk,
  vpn_client_ip_start = vpn_client_ip_start,
  vpn_client_ip_end = vpn_client_ip_end,
  vpn_server_ip = vpn_server_ip,
  effective_vpn_username = effective_vpn_username,
  effective_vpn_password = effective_vpn_password
})}
%{endif}

%{if custom_post_config != ""}
# User-provided post-configuration
${custom_post_config}
%{endif} 
