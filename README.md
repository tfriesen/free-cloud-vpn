# free-cloud-vpn

## Goal

To make it easy to set up and use a fully private VPN using only free tier offerings on popular cloud services. Further, the VPN should support as many connection modes as possible in order to maximize the ability to punch through restrictive or heavily surveilled networks.

Also, I wanted to experiment with codegen AI agents, so something like 90% of this project was written with Copilot and/or Cursor. Free tier, obviously. Mixed results, tbh. Impressive what it can do, but definitely needs some serious hand-holding and double-checking.

## Details

Automatically sets up a free-tier VM in Google Cloud and Oracle Cloud. This GCP VM has 2 vCPU cores and 1 GB of RAM. This Oracle VM has 4 vCPU cores and a whopping 24GB of RAM! 

Each supports the following methods of connecting and/or tunnelling:

1. SSH on port TCP/22 and any others you want!
2. HTTPS proxy on TCP/443. Specify a cert or generate a self-signed one. (Letsencrypt support coming, probably!)
3. DNS tunnel (DNS config must be completed externally. Relay mode sucks)
4. Pingtunnel, see https://github.com/esrrhs/pingtunnel?tab=readme-ov-file Works well! But note it is not encrypted. And looks like a DoS to your cloud provider.
5. Wireguard. Generate a client key and pass it in.
6. IPSec/IKEv2 VPN (via PSK)

### Limits

1. 200GB of outbound transfer per month on GCP, or 10TB outbound on Oracle.

## Install and setup

Since this is still pretty early in development, a lot of the setup is manual. Best done on Linux/WSL, maybe Mac.

You will need to:

1. Create the cloud accounts and projects and obtain appropriate cloud provider credentials and store them in `cloud/.env`. See `cloud/.env.example`. How to do this is outside the scope of this README; Google it, lots of guides exist
2. Install opentofu (or terraform). `apt install -y opentofu` should suffice.
3. Set appropriate config variables in `cloud/main.auto.tfvars`. See `cloud/main.auto.tfvars.example`. The default values should work for most people, but you can customize them as needed.
4. `cd` into `cloud/`, and run `tofu init`
5. Run `tofu apply`, and if everything looks good, it should deploy your VPN
6. If everything worked, the output should give you most of what you need to connect. IP address, etc. However, any generated passwords, secrets or private keys will be redacted. To view those, run `tofu output -show-sensitive`. Be warned as this information is stored in your tfstate file on-disk and unencrypted
7. Use your proxies as you see fit. How you can leverage these services to proxy or VPN your traffic is outside the scope of this document. If it's privacy you're after, mind your DNS!

### DynDNS

If you have a domain that you'd like to use for the VMs, you can either configure them manually, or use the `custom_pre_config` inputs to set them up automatically. For example, if you have a domain registered with Hurricane Electric, you can use the following setting in your `main.auto.tfvars`:

```
custom_pre_config = "if [ $${cloud_provider} = \"google\" ]; then curl 'https://dyn.dns.he.net/nic/update?hostname=vpn1.mydomain.com&password=12345'; elif [ $${cloud_provider} = \"oracle\" ]; then curl 'https://dyn.dns.he.net/nic/update?hostname=vpn2.mydomain.com&password=12345'; fi"
```

The will let you access your VMs at `vpn1.mydomain.com` and `vpn2.mydomain.com`. Adapt as necessary for other DynDNS providers, like No-IP or Cloudflare or DuckDNS.

## Testing

The `cloud/tests` directory contains a script to test the VMs. Handy to check if your instance and its services came up correctly. It will try to read your config based on the output of your terraform state file and the inputs you specify in your aut.tfvars file. It will test the following services, if they are configured:

* SSH
* HTTPS proxy
* Wireguard
* DNS tunnel
* Pingtunnel (doesn't currently work correctly)
* IPSec

To run the tests, follow the setup instructions in `cloud/tests/README.md`.

Most of the test currently only test for connectivity - if the service is up and listening. The HTTPS proxy test, however, will do a more proper end-to-end test, which makes it a handy indicator for the state of the connectivity of the other components.

## Roadmap

* Use serverless functionality to proxy HTTP connections (eg tell a lambda to fetch HTTP resources for you)
* Explore running service on UDP/443 and/or tunnelling over QUIC
* More cloud providers!
* v6 support. Google charges for v6, oddly enough - only available on their 'Premium' network. Unsure about Oracle. Could be a good way of getting around network controls, v6 is often neglected by network engineers.
* Forking the pingtunnel project and adding encryption would be a good idea.

## Known issues

* Pingtunnel works great, but not encrypted. And the 'password' is a 32-bit int that's sent in the clear. AND your cloud provider will probably send you nasty warnings about DoS'ing people
* SSH keys on GCP are bugged. They're set almost properly. You'll have to login to the GCP console, edit the config, and then just save it without changing anything. Then they'll work right.
* Can't ping the other side of the wireguard tunnel. Traffic fowards fine, once you get the routes set up. Probably just a firewall/NAT issue. Probably true of the other tunnels as well, currently untested.
* Probably need to adjust the Oracle firewall some as well.

