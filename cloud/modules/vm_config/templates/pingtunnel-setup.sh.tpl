# Install build dependencies for pingtunnel
DEBIAN_FRONTEND=noninteractive apt-get install -y wget unzip

# Download and install pingtunnel
cd /tmp
# Use the architecture variable to download the correct version
if [ "${arch}" = "arm64" ]; then
  wget https://github.com/tfriesen/pingtunnel-encrypted/releases/download/latest/pingtunnel_linux_arm.zip
  unzip pingtunnel_linux_arm.zip
elif [ "${arch}" = "x86_64" ]; then
  wget https://github.com/tfriesen/pingtunnel-encrypted/releases/download/latest/pingtunnel_linux_amd64.zip
  unzip pingtunnel_linux_amd64.zip
else
  # Default to x86_64 if arch is not recognized
  wget https://github.com/tfriesen/pingtunnel-encrypted/releases/download/latest/pingtunnel_linux_amd64.zip
  unzip pingtunnel_linux_amd64.zip
fi
chmod +x pingtunnel
mv pingtunnel /usr/local/bin/

# Create pingtunnel systemd service
cat > /etc/systemd/system/pingtunnel.service << 'PINGTUNNELSERVICE'
[Unit]
Description=Pingtunnel Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pingtunnel -type server -key ${pingtunnel_key} -nolog 1 -noprint 1 -encrypt aes128 -encrypt-key ${pingtunnel_aes_key}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
PINGTUNNELSERVICE

# Disable system default ping to avoid conflicts
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all

# Add iptables rules
iptables -I INPUT -p icmp --icmp-type 8 -j ACCEPT

# AI seems to think this is necessary, but I am less certain. Retained for reference
#ETH0=$(ip -o -4 route show to default | awk '{print $5}')
#iptables -t nat -A POSTROUTING -o $ETH0 -j MASQUERADE

# Enable and start pingtunnel
systemctl daemon-reload
systemctl enable pingtunnel
systemctl start pingtunnel 
