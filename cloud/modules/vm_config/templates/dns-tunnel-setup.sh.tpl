DEBIAN_FRONTEND=noninteractive apt-get install -y iodine

# -n auto won't work as externalip.net is kaput, but iodine won't let the client specify the server IP :/
# Without, you can't use raw mode, which has MUCH better performance
PUB_IP=$(curl -q -s --max-time 5 api.ipify.org || true)

# Configure iodine DNS tunnel
cat > /etc/default/iodine << 'IODINECONF'
# Configuration for iodine DNS tunnel
START_IODINED="true"

# The tunnel password
IODINED_PASSWORD="${effective_dns_password}"

# Additional options.
IODINED_ARGS="-n __PUBLIC_IP__ -c ${dns_tunnel_config.server_ip} ${dns_tunnel_config.domain}"
IODINECONF

# Replace placeholder with detected public IPv4 using sed (post-write)
if [ -n "$PUB_IP" ]; then
  sed -i "s/__PUBLIC_IP__/$PUB_IP/g" /etc/default/iodine
else
  echo "WARN: Could not determine public IP; leaving placeholder in /etc/default/iodine" >&2
fi

#Firewall rules for iodine server and forwarding.
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -i dns0 -j ACCEPT
iptables -t nat -I POSTROUTING -o $(ls /sys/class/net/ | grep en) -j MASQUERADE

chmod 600 /etc/default/iodine
systemctl unmask iodined
systemctl enable iodined
systemctl restart iodined 
