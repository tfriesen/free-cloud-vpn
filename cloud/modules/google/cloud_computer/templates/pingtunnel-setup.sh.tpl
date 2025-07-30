# Install build dependencies for pingtunnel
DEBIAN_FRONTEND=noninteractive apt-get install -y wget unzip

# Download and install pingtunnel
cd /tmp
# TODO: Make this adaptable based on architeture (eg arm64, x86)
wget https://github.com/esrrhs/pingtunnel/releases/download/2.8/pingtunnel_linux_amd64.zip
unzip pingtunnel_linux_amd64.zip
chmod +x pingtunnel
mv pingtunnel /usr/local/bin/

# Create pingtunnel systemd service
cat > /etc/systemd/system/pingtunnel.service << 'PINGTUNNELSERVICE'
[Unit]
Description=Pingtunnel Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pingtunnel -type server -key ${pingtunnel_key} -nolog 1 -noprint 1
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
PINGTUNNELSERVICE

# Disable system default ping to avoid conflicts
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all

# Enable and start pingtunnel
systemctl daemon-reload
systemctl enable pingtunnel
systemctl start pingtunnel 
