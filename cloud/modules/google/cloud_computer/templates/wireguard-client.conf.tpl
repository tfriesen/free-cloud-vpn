[Interface]
Address = ${client_ip}
# PrivateKey = <insert your client private key here>

[Peer]
PublicKey = ${server_pubkey}
Endpoint = ${server_ip}:${server_port}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = 25
