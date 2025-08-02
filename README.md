# free-cloud-vpn

## Goal

To make it easy to set up and use a fully private VPN using only free tier offerings on popular cloud services. Further, the VPN should support as many connection modes as possible in order to maximize the ability to punch through restrictive or heavily surveilled networks.

Also, I wanted to experiment with codegen AI agents, so something like 90% of this project was written with Copilot and/or Cursor. Free tier, obviously. Mixed results, tbh. Impressive what it can do, but definitely needs some serious hand-holding and double-checking.

## Details

Automatically sets up a free-tier VM in Google Cloud. This VM has 2 vCPU cores and 1 GB of RAM. It supports the following methods of connecting and/or tunnelling:

1. SSH on port TCP/22 and any others you want!
2. HTTPS proxy on TCP/443. Specify a cert or generate a self-signed one. (Letsencrypt support coming, probably!)
3. DNS tunnel (DNS config must be completed externally. Relay mode sucks)
4. Pingtunnel, see https://github.com/esrrhs/pingtunnel?tab=readme-ov-file Works well! But note it is not encrypted. And looks like a DoS to your cloud provider.
5. Wireguard. Generate a client key and pass it in.
6. IPSec/IKEv2 VPN (via PSK)

### Limits

1. 200GB of outbound transfer per month

## Install and setup

Since this is still pretty early in development, a lot of the setup is manual. Best done on Linux/WSL, maybe Mac.

You will need to:

1. Create the cloud accounts and projects and obtain appropriate cloud provider credentials (specfically, Google Cloud) and store them in `cloud/.env`. See `cloud/.env.example`. How to do this is outside the scope of this README; Google it, lots of guides exist
2. Install opentofu (or terraform). `apt install -y opentofu` should suffice.
3. Optionaly, set appropriate config variables in `cloud/main.auto.tfvars`. See `cloud/main.auto.tfvars.example`
4. `cd` into `cloud/`, and run `tofu init`
5. Run `tofu apply`, and if everything looks good, it should deploy your VPN
6. If everything worked, the output should give you most of what you need to connect. IP address, etc. However, any generated passwords, secrets or private keys will be redacted. To view those, run `tofu output -show-sensitive`
7. Use your proxies as you see fit. How you can leverage these services to proxy or VPN your traffic is outside the scope of this document. If it's privacy you're after, mind your DNS!

## Roadmap

* Use serverless functionality to proxy HTTP connections (eg tell a lambda to fetch HTTP resources for you)
* Explore running service on UDP/443 and/or tunnelling over QUIC
* More cloud providers!

## Known issues

* Pingtunnel works great, but not encrypted. And your cloud provider will probably send you nasty warnings about DoS'ing people
* SSH keys on GCP are bugged. They're set almost properly. You'll have to login to the GCP console, edit the config, and then just save it without changing anything. Then they'll work right.
* Can't ping the other side of the wireguard tunnel. Traffic fowards fine, once you get the routes set up. Probably just a firewall/NAT issue.
