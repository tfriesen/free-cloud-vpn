# Install WireGuard
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard

# Convert private key from PEM to wg format.
echo "${wireguard_private_key}" > /etc/wireguard/private.pem && openssl pkey -in /etc/wireguard/private.pem -outform DER -out private_key.der && dd if=private_key.der bs=1 skip=$(($(stat -c %s private_key.der) - 32)) count=32 2>/dev/null | base64 > /etc/wireguard/private.key
wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key

curl -X PUT -H "Metadata-Flavor: Google" --data "$(cat /etc/wireguard/public.key)" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/${vm_guest_attr_namespace}/${wg_pubkey_attr_key} 

# Create WireGuard configuration
cat > /etc/wireguard/wg0.conf << WIREGUARDCONF
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
Address = ${wireguard_server_ip}
ListenPort = ${wireguard_config.port}

[Peer]
PublicKey = ${wireguard_config.client_public_key}
AllowedIPs = ${wireguard_config.client_ip}

WIREGUARDCONF
chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding for WireGuard
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

#Firewall rules for forwarding. Not sure why the INPUT rule is needed, but it is.
iptables -A INPUT -i wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o $(ls /sys/class/net/ | grep ens) -j MASQUERADE

# Enable and start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0 
