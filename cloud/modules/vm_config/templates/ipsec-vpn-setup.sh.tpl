# Configure IPSec/IKEv2 VPN (PSK-based)
DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins

# Configure IPSec
cat > /etc/ipsec.conf << 'IPSECCONF'
config setup
    charondebug="ike 2, knl 2, cfg 2, net 1, esp 2, dmn 2,  mgr 2"
    uniqueids=no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2
    authby=psk

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=aes256-sha512-sha256-sha1-curve25519-modp1024-modp2048!
    esp=aes256-sha512-sha256-sha1-curve25519-modp1024-modp2048!
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@server
    leftsubnet=0.0.0.0/0
    leftauth=psk
    right=%any
    rightid=%any
    rightauth=psk
    rightsourceip=${vpn_client_ip_start}-${vpn_client_ip_end}
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
IPSECCONF

# Configure IPSec secrets
cat > /etc/ipsec.secrets << IPSECSECRETS
: PSK "${effective_ipsec_psk}"
IPSECSECRETS
chmod 600 /etc/ipsec.secrets

# Configure strongSwan
cat > /etc/strongswan.conf << 'STRONGSWANCONF'
charon {
    load_modular = yes
    plugins {
        include strongswan.d/charon/*.conf
    }
    dns1 = 8.8.8.8
    dns2 = 8.8.4.4
    nbns1 = 8.8.8.8
    nbns2 = 8.8.4.4
}

include strongswan.d/*.conf
STRONGSWANCONF

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.d/60-vpn.conf
sysctl -p /etc/sysctl.d/60-vpn.conf

# Restart services
systemctl enable ipsec
systemctl restart ipsec 
