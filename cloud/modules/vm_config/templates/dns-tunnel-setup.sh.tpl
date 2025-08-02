DEBIAN_FRONTEND=noninteractive apt-get install -y iodine

# Configure iodine DNS tunnel
cat > /etc/default/iodine << 'IODINECONF'
# Configuration for iodine DNS tunnel
START_IODINED="true"

# The tunnel password
IODINED_PASSWORD="${effective_dns_password}"

# Additional options. -n auto won't work as externalip.net is kaput, but iodine won't let the client specify the server IP :/
# Without, you can't use raw mode, which has MUCH better performance
IODINED_ARGS="-n `curl 4.ipquail.com` -c ${dns_tunnel_config.server_ip} ${dns_tunnel_config.domain}"
IODINECONF

#Firewall rules for forwarding. Not sure why the INPUT rule is needed, but it is.
iptables -A INPUT -i dns0 -j ACCEPT
iptables -t nat -A POSTROUTING -o $(ls /sys/class/net/ | grep ens) -j MASQUERADE

chmod 600 /etc/default/iodine
systemctl unmask iodined
systemctl enable iodined
systemctl restart iodined 
