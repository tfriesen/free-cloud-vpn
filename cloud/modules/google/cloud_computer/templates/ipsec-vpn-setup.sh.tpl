# Configure IPSec/IKEv2 VPN
DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins

# Generate CA certificate
ipsec pki --gen --type rsa --size 2048 --outform pem > /etc/ipsec.d/private/ca-key.pem
ipsec pki --self --ca --lifetime 3650 --in /etc/ipsec.d/private/ca-key.pem --type rsa --dn "CN=VPN CA" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem

# Generate server certificate
ipsec pki --gen --type rsa --size 2048 --outform pem > /etc/ipsec.d/private/server-key.pem
ipsec pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa | ipsec pki --issue --lifetime 3650 --cacert /etc/ipsec.d/cacerts/ca-cert.pem --cakey /etc/ipsec.d/private/ca-key.pem --dn "CN=${effective_vpn_username}" --san "${effective_vpn_username}" --flag serverAuth --flag ikeIntermediate --outform pem > /etc/ipsec.d/certs/server-cert.pem

# Configure IPSec
cat > /etc/ipsec.conf << 'IPSECCONF'
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2,  mgr 2"
    uniqueids=no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2
    authby=secret

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=aes256-sha1-modp1024,3des-sha1-modp1024!
    esp=aes256-sha1,3des-sha1!
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@server
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=${vpn_client_ip_start}-${vpn_client_ip_end}
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
IPSECCONF

# Configure IPSec secrets
cat > /etc/ipsec.secrets << IPSECSECRETS
: RSA server-key.pem
${effective_vpn_username} : EAP "${effective_vpn_password}"
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
systemctl enable strongswan
systemctl restart strongswan 
