# Configure IPSec/L2TP VPN
DEBIAN_FRONTEND=noninteractive apt-get install -y libreswan xl2tpd

cat > /etc/ipsec.conf << 'IPSECCONF'
config setup
    virtual-private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    protostack=netkey
    uniqueids=no

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftid=%defaultroute
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
    encapsulation=yes
IPSECCONF

# Configure IPSec secrets
cat > /etc/ipsec.secrets << IPSECSECRETS
%defaultroute : PSK "${effective_ipsec_psk}"
IPSECSECRETS
chmod 600 /etc/ipsec.secrets

# Configure xl2tpd
cat > /etc/xl2tpd/xl2tpd.conf << XL2TPDCONF
[global]
ipsec saref = yes
saref refinfo = 30

[lns default]
ip range = ${vpn_client_ip_start}-${vpn_client_ip_end}
local ip = ${vpn_server_ip}
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
XL2TPDCONF

# Configure PPP options
cat > /etc/ppp/options.xl2tpd << PPPOPTIONS
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
mtu 1400
mru 1400
proxyarp
lcp-echo-failure 4
lcp-echo-interval 30
connect-delay 5000
name l2tpd
PPPOPTIONS

# Add VPN user
cat > /etc/ppp/chap-secrets << CHAPSECRETS
${effective_vpn_username} l2tpd "${effective_vpn_password}" *
CHAPSECRETS
chmod 600 /etc/ppp/chap-secrets

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
systemctl enable xl2tpd
systemctl restart ipsec
systemctl restart xl2tpd 
