DEBIAN_FRONTEND=noninteractive apt-get install -y iodine

# Configure iodine DNS tunnel
cat > /etc/default/iodine << 'IODINECONF'
# Configuration for iodine DNS tunnel
START_IODINED="true"

# The tunnel password
IODINED_PASSWORD="${effective_dns_password}"

# Additional options
IODINED_ARGS="-c ${dns_tunnel_config.server_ip} ${dns_tunnel_config.domain}"
IODINECONF

chmod 600 /etc/default/iodine
systemctl unmask iodined
systemctl enable iodined
systemctl restart iodined 
