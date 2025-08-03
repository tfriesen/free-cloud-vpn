# VM Service Testing Suite

This directory contains Python scripts to test that your Free Cloud VPN services are running correctly on deployed VMs.

## Overview

The test suite reads your Terraform state file to discover running VMs and tests that each configured service is listening on the appropriate ports. It performs both external port connectivity tests and can optionally verify services via SSH.

## Setup

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt

   ```

   Hahahaha - nice one AI. God luck with that, though. God, I love python but I fucking hate python venvs. pip complains about 'externally-managed-environment', and tells you to use pipx. Well, pipx doesn't support `-r requirements.txt`, because the developers have a huge stick up their ass, and don't give a shit about the actual users that are using their software, so you have to type each package individually. Then, while pipx 'works', and installs the packages, but when you run python, it can't find the packges, for some fucking opaque reason. So you have to remember all the subtle commands for setting up a venv manually, and/or use special binary paths. The following probably works more reliably, but YMMV:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

   What an awful user experience.

2. **Configure environment (optional):**
   ```bash
   cp .env.example .env
   # Edit .env with your SSH key path and other configuration
   ```

## Usage

Run the test suite from the `tests` directory:

```bash
cd tests
python test_vm_services.py
```

## What It Tests

The script automatically detects which services should be running based on your Terraform configuration and tests:

### Always Tested Services
- **SSH**: Tests all ports configured in the `ssh_ports` variable (default: 22, 80, 8080, 3389, 993, 995, 587, 465, 143, 110, 21, 25)
- **HTTPS Proxy**: Tests port 443 (stunnel + tinyproxy)

### Conditionally Tested Services
Based on your `main.auto.tfvars` configuration:

- **IPsec VPN** (if `ipsec_vpn_config.enable = true`):
  - UDP port 500 (IKE)
  - UDP port 4500 (NAT-T)

- **WireGuard** (if `wireguard_config.enable = true`):
  - UDP port specified in `wireguard_config.port` (default: 51820)

- **DNS Tunnel** (if `dns_tunnel_config.enable = true`):
  - UDP port 53 (iodine DNS tunnel)

- **Pingtunnel** (if `enable_pingtunnel = true`):
  - ICMP connectivity test

## Test Methods

1. **Direct Port Testing**: Attempts to connect to each service port from your local machine
2. **SSH Verification**: If direct tests fail and SSH is configured, verifies services are listening via SSH
3. **ICMP Testing**: Uses ping to test ICMP connectivity for pingtunnel

## Configuration

### Environment Variables (.env file)

- `SSH_PRIVATE_KEY_PATH`: Path to SSH private key for connecting to VMs
- `NETWORK_TIMEOUT`: Timeout for network tests in seconds (default: 10)
- `VERBOSE`: Enable verbose output (true/false)

### Supported Cloud Providers

- Google Cloud Platform
- Oracle Cloud Infrastructure
- AWS (Lambda functions - not currently tested by this suite)

## Output

The script provides:
- Real-time test results for each service
- Summary of all tests with pass/fail status
- Overall success rate

Example output:
```
Free Cloud VPN - VM Service Port Tests
==================================================

Testing VM: google (1.2.3.4)
  FQDN: vpn.example.com
  Testing SSH-22 (tcp:22)...
    ✓ PASS: SSH daemon on port 22
  Testing HTTPS-Proxy (tcp:443)...
    ✓ PASS: HTTPS proxy via stunnel
  Testing WireGuard (udp:51820)...
    ✓ PASS: WireGuard VPN on port 51820

==================================================
SUMMARY
==================================================

google_1.2.3.4:
  ✓ SSH-22
  ✓ HTTPS-Proxy
  ✓ WireGuard

Overall: 3/3 tests passed
🎉 All services are working correctly!
```

## Troubleshooting

### Common Issues

1. **"No VMs found in Terraform state"**
   - Ensure you've run `terraform apply` and have active VMs
   - Check that `terraform.tfstate` exists in the parent directory

2. **Port tests failing**
   - Verify firewall rules are correctly applied
   - Check that services are actually running on the VM
   - Ensure your local network allows outbound connections to the tested ports

3. **SSH verification not working**
   - Set `SSH_PRIVATE_KEY_PATH` in your `.env` file
   - Ensure the SSH key has correct permissions (600)
   - Verify the SSH key matches what was deployed to the VM

### Manual Verification

If tests fail, you can manually verify services:

```bash
# SSH to your VM
ssh -i /path/to/key clouduser@your-vm-ip

# Check listening ports
sudo ss -tlnp  # TCP ports
sudo ss -ulnp  # UDP ports

# Check service status
sudo systemctl status sshd
sudo systemctl status stunnel4
sudo systemctl status wg-quick@wg0
sudo systemctl status ipsec
sudo systemctl status iodined
sudo systemctl status pingtunnel
```

## Future Enhancements

Planned improvements:
- Service-specific functional tests (e.g., actual VPN connection tests)
- Performance benchmarking
- Support for custom service configurations
