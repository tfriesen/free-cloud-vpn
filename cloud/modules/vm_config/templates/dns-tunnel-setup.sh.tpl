DEBIAN_FRONTEND=noninteractive apt-get install -y iodine

# -n auto won't work as externalip.net is kaput, but iodine won't let the client specify the server IP :/
# Without, you can't use raw mode, which has MUCH better performance
IODINE_IP=`curl api.ipify.org`

# Configure iodine DNS tunnel
cat > /etc/default/iodine << 'IODINECONF'
# Configuration for iodine DNS tunnel
START_IODINED="true"

# The tunnel password
IODINED_PASSWORD="${effective_dns_password}"

# Additional options.
IODINED_ARGS="-n $${IODINE_IP} -c ${dns_tunnel_config.server_ip} ${dns_tunnel_config.domain}"
IODINECONF

#Firewall rules for iodine server and forwarding.
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -i dns0 -j ACCEPT
iptables -t nat -I POSTROUTING -o $(ls /sys/class/net/ | grep en) -j MASQUERADE

chmod 600 /etc/default/iodine
systemctl unmask iodined
systemctl enable iodined
systemctl restart iodined 
