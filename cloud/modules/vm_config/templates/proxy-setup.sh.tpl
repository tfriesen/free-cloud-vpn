# Configure tinyproxy to listen only on localhost
DEBIAN_FRONTEND=noninteractive apt-get install -y tinyproxy apache2-utils stunnel4

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
BasicAuth clouduser ${effective_proxy_password}
TINYPROXYCONF

# Create SSL directory
mkdir -p /etc/stunnel/ssl
%{if has_external_https_cert}
# Use externally provided certificate and key
cat > /etc/stunnel/ssl/cert.pem << 'CERT'
${https_proxy_external_cert_pem}
CERT

cat > /etc/stunnel/ssl/key.pem << 'KEY'
${https_proxy_external_key_pem}
KEY
%{else}
%{if has_proxy_domain}
# Install certbot for LetsEncrypt
DEBIAN_FRONTEND=noninteractive apt-get install -y certbot 

# Get LetsEncrypt certificate
certbot certonly --standalone --non-interactive --agree-tos --email admin@${https_proxy_domain} -d ${https_proxy_domain}

# Link certificates
ln -sf /etc/letsencrypt/live/${https_proxy_domain}/fullchain.pem /etc/stunnel/ssl/cert.pem
ln -sf /etc/letsencrypt/live/${https_proxy_domain}/privkey.pem /etc/stunnel/ssl/key.pem

# Setup cert renewal hook
cat > /etc/letsencrypt/renewal-hooks/deploy/stunnel << 'RENEWHOOK'
#!/bin/bash
systemctl restart stunnel4
RENEWHOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/stunnel
%{else}
# Use self-signed certificate
cat > /etc/stunnel/ssl/cert.pem << 'CERT'
${tls_self_signed_cert_proxy}
CERT

cat > /etc/stunnel/ssl/key.pem << 'KEY'
${tls_private_key_proxy_cert}
KEY
%{endif}
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

iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# Enable and start services
systemctl enable stunnel4
systemctl enable tinyproxy
systemctl restart tinyproxy
systemctl restart stunnel4

 
