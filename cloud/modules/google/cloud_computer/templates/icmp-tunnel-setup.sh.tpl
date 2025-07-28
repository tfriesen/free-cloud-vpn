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
