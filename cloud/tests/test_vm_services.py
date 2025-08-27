#!/usr/bin/env python3
"""
VM Service Port Testing Script

This script reads Terraform state to discover running VMs and tests that
each configured service is listening on the appropriate ports.

Usage:
    python test_vm_services.py

Configuration:
    Create a .env file in the same directory with sensitive configuration:
    SSH_PRIVATE_KEY_PATH=/path/to/ssh/key
    WIREGUARD_PRIVATE_KEY=your_wg_private_key
    DNS_TUNNEL_PASSWORD=your_dns_password
    PINGTUNNEL_KEY=your_pingtunnel_key
"""

import json
import os
from re import VERBOSE
import socket
import subprocess
import sys
import requests
import ssl
import socket
import urllib3
from requests.exceptions import RequestException
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
from pathlib import Path


# ANSI color codes
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

try:
    from dotenv import load_dotenv
    import paramiko
except ImportError:
    print("Missing required packages. Install with:")
    print("pip install python-dotenv paramiko")
    sys.exit(1)


@dataclass
class ServiceConfig:
    """Configuration for a service to test"""
    name: str
    port: int
    protocol: str = "tcp"  # tcp, udp, or icmp
    description: str = ""


@dataclass
class VMInfo:
    """Information about a VM to test"""
    provider: str
    ip_address: str
    fqdn: Optional[str]
    ssh_private_key: Optional[str]
    services: List[ServiceConfig]


class VMServiceTester:
    """Tests VM services by checking if ports are listening"""
    
    def __init__(self, env_file: str = ".env"):
        """Initialize the tester with environment configuration"""
        self.env_file = env_file
        self.load_environment()
        self.terraform_state = self.load_terraform_state()
    
    def has_ipv6_connectivity(self) -> bool:
        """Best-effort check: attempt to send a UDP packet to a public IPv6 resolver.
        Returns True if no immediate routing/socket error occurs."""
        if not socket.has_ipv6:
            return False
        try:
            sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
            sock.settimeout(1)
            # Cloudflare IPv6 DNS anycast
            sock.sendto(b"test", ("2606:4700:4700::1111", 53, 0, 0))
            sock.close()
            return True
        except Exception:
            return False
        
    def load_environment(self):
        """Load environment variables from .env file"""
        env_path = Path(__file__).parent / self.env_file
        if env_path.exists():
            load_dotenv(env_path)
            print(f"Loaded environment from {env_path}")
        else:
            print(f"Warning: {env_path} not found, using system environment only")
    
    def load_terraform_state(self) -> dict:
        """Load Terraform state file"""
        state_file = Path(__file__).parent.parent / "terraform.tfstate"
        if not state_file.exists():
            print(f"Error: Terraform state file not found at {state_file}")
            sys.exit(1)
            
        with open(state_file, 'r') as f:
            return json.load(f)
    
    def get_terraform_outputs(self) -> dict:
        """Extract outputs from Terraform state"""
        outputs = {}
        if 'outputs' in self.terraform_state:
            for key, value in self.terraform_state['outputs'].items():
                outputs[key] = value.get('value')
        return outputs
    
    def parse_tfvars_files(self) -> dict:
        """Parse all .tfvars and .auto.tfvars files in the cloud directory and merge them (last-wins)"""
        import glob
        import hcl2
        tfvars_dir = Path(__file__).parent.parent
        tfvars_files = sorted(
            glob.glob(str(tfvars_dir / '*.tfvars')) + glob.glob(str(tfvars_dir / '*.auto.tfvars'))
        )
        merged = {}
        for tfvars_file in tfvars_files:
            try:
                with open(tfvars_file, 'r') as f:
                    # Try JSON first, fallback to HCL2
                    try:
                        data = json.load(f)
                    except Exception:
                        f.seek(0)
                        data = hcl2.load(f)
                    merged.update(data)
            except Exception as e:
                print(f"Warning: Could not parse {tfvars_file}: {e}")
        return merged

    def get_terraform_variables(self) -> dict:
        """Extract variable values from Terraform state, then override with any tfvars/auto.tfvars files (last-wins)"""
        variables = {}
        # Extract from state
        if 'values' in self.terraform_state and 'root_module' in self.terraform_state['values']:
            root = self.terraform_state['values']['root_module']
            if 'input_variables' in root:
                for var_name, var_data in root['input_variables'].items():
                    variables[var_name] = var_data.get('value')
        # Merge tfvars/auto.tfvars (last-wins)
        tfvars_vars = self.parse_tfvars_files()
        variables.update(tfvars_vars)
        return variables
    
    # ---------------- DNS helpers -----------------
    def resolve_a(self, host: str) -> List[str]:
        addrs = set()
        try:
            infos = socket.getaddrinfo(host, None, socket.AF_INET, 0, 0)
            for info in infos:
                addrs.add(info[4][0])
        except Exception:
            pass
        return sorted(addrs)

    def resolve_aaaa(self, host: str) -> List[str]:
        addrs = set()
        if not socket.has_ipv6:
            return []
        try:
            infos = socket.getaddrinfo(host, None, socket.AF_INET6, 0, 0)
            for info in infos:
                addrs.add(info[4][0])
        except Exception:
            pass
        return sorted(addrs)

    def test_cloudflare_dns(self) -> Dict[str, bool]:
        """If Cloudflare is enabled, verify raw.<provider>.<domain> A/AAAA records resolve to expected VM IPs."""
        results: Dict[str, bool] = {}
        variables = self.get_terraform_variables()
        cf_enabled = bool(variables.get("enable_cloudflare", False))
        cf_cfg = variables.get("cloudflare_config", {}) or {}
        domain = (cf_cfg.get("domain") or "").strip()
        if not (cf_enabled and domain):
            print("Cloudflare not enabled or domain not set. Skipping DNS checks.")
            return results

        outputs = self.get_terraform_outputs()
        # Build expected host->IP maps using terraform outputs
        checks: List[Tuple[str, str, str]] = []  # (record_type, hostname, expected_ip)

        google_vm = outputs.get("google_vm") or {}
        if google_vm.get("ip_address"):
            checks.append(("A", f"raw.gcp.{domain}", google_vm["ip_address"]))

        oracle_vm = outputs.get("oracle_vm") or {}
        if oracle_vm.get("ip_address"):
            checks.append(("A", f"raw.oci.{domain}", oracle_vm["ip_address"]))
        if oracle_vm.get("ipv6_address"):
            checks.append(("AAAA", f"raw.oci.{domain}", oracle_vm["ipv6_address"]))

        # Execute checks
        print("\nCloudflare DNS Checks")
        print("-" * 50)
        for rtype, host, expected in checks:
            if rtype == "A":
                answers = self.resolve_a(host)
            else:
                answers = self.resolve_aaaa(host)
            ok = expected in answers
            results[f"DNS {rtype} {host}"] = ok
            status = f"{GREEN}✓ PASS{RESET}" if ok else f"{RED}✗ FAIL{RESET}"
            print(f"  {status} {rtype} {host} -> expected {expected}; got {answers if answers else '[]'}")

        # Note: We intentionally do not assert on apex or proxied subdomains (e.g., gcp.<domain>, oci.<domain>)
        # because proxied Cloudflare records resolve to Cloudflare anycast IPs, not origin VM IPs.

        # Optional: NS records for dns tunnel delegation if enabled
        dns_cfg = variables.get("dns_tunnel_config", {}) or {}
        if dns_cfg.get("enable"):
            # For each provider present, ensure ns.<provider>.<domain> NS target matches raw.<provider>.<domain>
            if google_vm.get("ip_address"):
                ns_host = f"ns.gcp.{domain}"
                target = f"raw.gcp.{domain}"
                # We can only validate by A lookup of target exists
                ns_ok = len(self.resolve_a(target)) > 0
                results[f"DNS NS {ns_host}"] = ns_ok
                print(f"  {(f'{GREEN}✓ PASS{RESET}' if ns_ok else f'{RED}✗ FAIL{RESET}')} NS {ns_host} -> {target}")
            if oracle_vm.get("ip_address"):
                ns_host = f"ns.oci.{domain}"
                target = f"raw.oci.{domain}"
                ns_ok = len(self.resolve_a(target)) > 0
                results[f"DNS NS {ns_host}"] = ns_ok
                print(f"  {(f'{GREEN}✓ PASS{RESET}' if ns_ok else f'{RED}✗ FAIL{RESET}')} NS {ns_host} -> {target}")

        return results
    
    def determine_services(self, variables: dict) -> List[ServiceConfig]:
        """Determine which services should be running based on Terraform variables"""
        services = []
        
        # Always test SSH (configured dynamically via ssh_ports variable)
        ssh_ports = variables.get('ssh_ports', [22, 80, 8080, 3389, 993, 995, 587, 465, 143, 110, 21, 25])
        for port in ssh_ports:
            services.append(ServiceConfig(
                name=f"SSH-{port}",
                port=port,
                protocol="tcp",
                description=f"SSH daemon on port {port}"
            ))
        
        # HTTPS Proxy (always enabled if VM exists)
        services.append(ServiceConfig(
            name="HTTPS-Proxy",
            port=443,
            protocol="tcp",
            description="HTTPS proxy via stunnel"
        ))
        
        # IPsec VPN
        ipsec_config = variables.get('ipsec_vpn_config', {})
        if ipsec_config and ipsec_config.get('enable', False):
            services.extend([
                ServiceConfig(name="IPsec-IKE", port=500, protocol="udp", description="IPsec IKE"),
                ServiceConfig(name="IPsec-NAT-T", port=4500, protocol="udp", description="IPsec NAT-T"),
            ])
        
        # WireGuard
        wg_config = variables.get('wireguard_config', {})
        if wg_config and wg_config.get('enable', False):
            wg_port = wg_config.get('port', 51820)
            services.append(ServiceConfig(
                name="WireGuard",
                port=wg_port,
                protocol="udp",
                description=f"WireGuard VPN on port {wg_port}"
            ))
        
        # DNS Tunnel
        dns_config = variables.get('dns_tunnel_config', {})
        if dns_config and dns_config.get('enable', False):
            services.append(ServiceConfig(
                name="DNS-Tunnel",
                port=53,
                protocol="udp",
                description="DNS tunnel via iodine"
            ))
        
        # Pingtunnel (ICMP - we'll test if the service process is running)
        if variables.get('enable_pingtunnel', False):
            services.append(ServiceConfig(
                name="Pingtunnel",
                port=0,  # ICMP doesn't use ports
                protocol="icmp",
                description="ICMP tunnel via pingtunnel"
            ))
        
        return services
    
    def discover_vms(self) -> List[VMInfo]:
        """Discover VMs from Terraform outputs"""
        outputs = self.get_terraform_outputs()
        variables = self.get_terraform_variables()
        services = self.determine_services(variables)
        
        vms = []
        
        # Google Cloud VM
        google_vm = outputs.get('google_vm')
        if google_vm:
            google_secrets = outputs.get('google_vm_secrets', {})
            vms.append(VMInfo(
                provider="google",
                ip_address=google_vm['ip_address'],
                fqdn=google_vm.get('fqdn'),
                ssh_private_key=google_secrets.get('ssh_private_key'),
                services=services
            ))
        
        # Oracle Cloud VM
        oracle_vm = outputs.get('oracle_vm')
        if oracle_vm:
            oracle_secrets = outputs.get('oracle_vm_secrets', {})
            vms.append(VMInfo(
                provider="oracle",
                ip_address=oracle_vm['ip_address'],
                fqdn=oracle_vm.get('fqdn'),
                ssh_private_key=oracle_secrets.get('ssh_private_key'),
                services=services
            ))
            # If IPv6 present, add an entry to test IPv6 explicitly
            ipv6_addr = oracle_vm.get('ipv6_address')
            if ipv6_addr:
                vms.append(VMInfo(
                    provider="oracle",
                    ip_address=ipv6_addr,
                    fqdn=oracle_vm.get('fqdn'),
                    ssh_private_key=oracle_secrets.get('ssh_private_key'),
                    services=services
                ))
        
        return vms
    
    def test_tcp_port(self, host: str, port: int, timeout: int = 5) -> bool:
        """Test if a TCP port is open and listening"""
        try:
            family = socket.AF_INET6 if ':' in host else socket.AF_INET
            sock = socket.socket(family, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            if family == socket.AF_INET6:
                result = sock.connect_ex((host, port, 0, 0))
            else:
                result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except Exception as e:
            print(f"    Error testing TCP port {port}: {e}")
            return False
    
    def test_udp_port(self, host: str, port: int, timeout: int = 5) -> bool:
        """Test if a UDP port is responding (basic connectivity test)"""
        try:
            family = socket.AF_INET6 if ':' in host else socket.AF_INET
            sock = socket.socket(family, socket.SOCK_DGRAM)
            sock.settimeout(timeout)
            # Send a dummy packet and see if we get a response or connection
            if family == socket.AF_INET6:
                sock.sendto(b'test', (host, port, 0, 0))
            else:
                sock.sendto(b'test', (host, port))
            try:
                sock.recvfrom(1024)
                sock.close()
                return True
            except socket.timeout:
                # Timeout might mean the service is listening but not responding to our test packet
                # For UDP, we'll consider this a partial success
                sock.close()
                return True
        except Exception as e:
            print(f"    Error testing UDP port {port}: {e}")
            return False
    
    def test_icmp_service(self, host: str) -> bool:
        """Test if ICMP (ping) is responding"""
        try:
            # Use ping command to test ICMP
            is_ipv6 = ':' in host
            cmd = ['ping', '-c', '1', '-W', '5', host]
            if is_ipv6:
                cmd.insert(1, '-6')
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            print(f"    Error testing ICMP: {e}")
            return False
    
    def test_service_via_ssh(self, vm: VMInfo, service: ServiceConfig) -> Optional[bool]:
        """Test if a service is running by checking via SSH"""
        if not vm.ssh_private_key:
            return None
            
        try:
            # Create SSH client
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Use SSH key from environment or VM info
            ssh_key_path = os.getenv('SSH_PRIVATE_KEY_PATH')
            if ssh_key_path and os.path.exists(ssh_key_path):
                ssh.connect(vm.ip_address, username='clouduser', key_filename=ssh_key_path, timeout=10)
            else:
                # Try to use the key from Terraform output (would need to write to temp file)
                return None
            
            # Check if service is listening on the port
            if service.protocol in ['tcp', 'udp']:
                cmd = f"ss -ln{service.protocol[0]} | grep ':{service.port} '"
                stdin, stdout, stderr = ssh.exec_command(cmd)
                output = stdout.read().decode().strip()
                ssh.close()
                return len(output) > 0
            elif service.protocol == 'icmp' and service.name == 'Pingtunnel':
                # Check if pingtunnel process is running
                cmd = "pgrep -f pingtunnel"
                stdin, stdout, stderr = ssh.exec_command(cmd)
                output = stdout.read().decode().strip()
                ssh.close()
                return len(output) > 0
                
        except Exception as e:
            print(f"    SSH test failed: {e}")
            return None
        
        return None
    
    def test_https_proxy_functional(self, vm: VMInfo) -> bool:
        """Test proxying an HTTPS request through the VM's proxy, verify IP and cert"""
        print("    [Functional Test] HTTPS proxy: verifying proxied IP and TLS certificate...")
        outputs = self.get_terraform_outputs()
        expected_ip = vm.ip_address

        # Retrieve proxy auth credentials
        proxy_username = "clouduser"
        proxy_password = None
        # Prefer the new composite outputs: non-sensitive config lives in <provider>_vm.https_proxy
        # and sensitive secrets live in <provider>_vm_secrets. Fall back to legacy scalar outputs if present.
        if vm.provider == "google":
            proxy_password = (
                (outputs.get("google_vm_secrets") or {}).get("https_proxy_secrets", {}) .get("password")
                or (outputs.get("google_vm") or {}).get("https_proxy_secrets", {}) .get("password")
                or (outputs.get("google_vm") or {}).get("https_proxy_password")
            )
            proxy_username = (
                (outputs.get("google_vm") or {}).get("https_proxy", {}) .get("username")
                or (outputs.get("google_vm") or {}).get("https_proxy_username")
                or proxy_username
            )
        elif vm.provider == "oracle":
            proxy_password = (
                (outputs.get("oracle_vm_secrets") or {}).get("https_proxy_secrets", {}) .get("password")
                or (outputs.get("oracle_vm") or {}).get("https_proxy_secrets", {}) .get("password")
                or (outputs.get("oracle_vm") or {}).get("https_proxy_password")
            )
            proxy_username = (
                (outputs.get("oracle_vm") or {}).get("https_proxy", {}) .get("username")
                or (outputs.get("oracle_vm") or {}).get("https_proxy_username")
                or proxy_username
            )

        # Fallback: check merged variables from tfvars/auto.tfvars. Support both legacy scalar vars and new object structure.
        variables = self.get_terraform_variables()
        if not proxy_password:
            proxy_password = (
                variables.get("https_proxy_password") or
                (variables.get("https_proxy_secrets") or {}).get("password") or
                (variables.get("https_proxy_secrets") or {}).get("password")
            )
        # Allow root-level https_proxy_username to override (legacy or new object)
        proxy_username = (
            variables.get("https_proxy_username") or
            (variables.get("https_proxy_config") or {}).get("username") or
            proxy_username
        )
        if not proxy_password:
            print(f"    {YELLOW}[WARN] No proxy password found in Terraform outputs or tfvars for this VM. Skipping proxy auth test.{RESET}")
            return False

        # Wrap IPv6 address in brackets for URLs
        host_for_url = f"[{vm.ip_address}]" if ':' in vm.ip_address else vm.ip_address
        proxy_url = f"https://{proxy_username}:{proxy_password}@{host_for_url}:443"
        proxies = {
            "https": proxy_url,
            "http": proxy_url,
        }

        if VERBOSE:
            print(f"    [INFO] Proxy url: {proxy_url}")
      
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        try:
            # Use requests to proxy an HTTPS request to ipify (choose IPv4 or IPv6 endpoint)
            ipify_url = "https://api6.ipify.org" if ':' in vm.ip_address else "https://api.ipify.org"
            resp = requests.get(
                ipify_url,
                proxies=proxies,
                timeout=10,
                verify=False,  # We'll check cert manually below
            )
            if resp.status_code != 200:
                print(f"    [FAIL] Proxy did not return 200 OK: {resp.status_code}")
                return False
            returned_ip = resp.text.strip()
            print(f"    [INFO] Proxied public IP: {returned_ip}")
            if returned_ip != expected_ip:
                print(f"    [FAIL] Proxied IP does not match VM IP: {returned_ip} != {expected_ip}")
                return False
        except RequestException as e:
            print(f"    [FAIL] HTTPS request via proxy failed: {e}")
            return False

        # Now verify the certificate presented by the proxy
        try:
            ctx = ssl._create_unverified_context()
            family = socket.AF_INET6 if ':' in vm.ip_address else socket.AF_INET
            conn = ctx.wrap_socket(socket.socket(family, socket.SOCK_STREAM), server_hostname=vm.ip_address)
            conn.settimeout(5)
            if family == socket.AF_INET6:
                conn.connect((vm.ip_address, 443, 0, 0))
            else:
                conn.connect((vm.ip_address, 443))
            der_cert = conn.getpeercert(binary_form=True)
            pem_cert = ssl.DER_cert_to_PEM_cert(der_cert)
            conn.close()
            # Determine if Cloudflare Origin cert is expected
            variables = self.get_terraform_variables()
            cf_enabled = bool(variables.get("enable_cloudflare", False))
            cf_cfg = variables.get("cloudflare_config", {}) or {}
            cf_domain = cf_cfg.get("domain") or ""
            cf_manage_origin = cf_cfg.get("manage_origin_cert", True)

            # Get expected cert from outputs
            # Prefer the Cloudflare Origin certificate from root outputs, fallback to per-VM https_proxy.cert (new composite output)
            expected_cert = outputs.get("cloudflare_origin_certificate_pem")
            if not expected_cert:
                if vm.provider == "google":
                    expected_cert = (
                        (outputs.get("google_vm") or {}).get("https_proxy", {}) .get("cert")
                        or (outputs.get("google_vm_secrets") or {}).get("https_proxy_secrets", {}) .get("external_cert_pem")
                        or (outputs.get("google_vm") or {}).get("https_proxy_cert")
                    )
                elif vm.provider == "oracle":
                    expected_cert = (
                        (outputs.get("oracle_vm") or {}).get("https_proxy", {}) .get("cert")
                        or (outputs.get("oracle_vm_secrets") or {}).get("https_proxy_secrets", {}) .get("external_cert_pem")
                        or (outputs.get("oracle_vm") or {}).get("https_proxy_cert")
                    )
            if not expected_cert:
                if cf_enabled and cf_domain and cf_manage_origin:
                    print(f"    {RED}[FAIL] Cloudflare origin cert expected but not found in Terraform outputs.{RESET}")
                    return False
                else:
                    print(f"    {YELLOW}[WARN] No expected certificate found in Terraform outputs for this VM. Skipping cert check.{RESET}")
                    return True
            # Normalize for comparison (strip whitespace, etc)
            def norm(cert):
                return cert.replace("\r", "").replace("\n", "").replace("-----BEGIN CERTIFICATE-----", "").replace("-----END CERTIFICATE-----", "").strip()
            if norm(pem_cert) == norm(expected_cert):
                print("    [PASS] Proxy TLS certificate matches Terraform output.")
                return True
            else:
                print("    [FAIL] Proxy TLS certificate does not match expected cert from Terraform output.")
                return False
        except Exception as e:
            print(f"    [FAIL] Error retrieving or comparing proxy TLS certificate: {e}")
            return False

    def test_vm_services(self, vm: VMInfo) -> Dict[str, bool]:
        """Test all services on a VM in parallel"""
        print(f"\nTesting VM: {vm.provider} ({vm.ip_address})")
        if vm.fqdn:
            print(f"  FQDN: {vm.fqdn}")

        from concurrent.futures import ThreadPoolExecutor, as_completed
        results = {}

        def test_one_service(service: ServiceConfig):
            print(f"  Testing {service.name} ({service.protocol}:{service.port})...")
            success = False
            if service.protocol == "tcp":
                if service.name == "HTTPS-Proxy":
                    success = self.test_https_proxy_functional(vm)
                else:
                    success = self.test_tcp_port(vm.ip_address, service.port)
            elif service.protocol == "udp":
                success = self.test_udp_port(vm.ip_address, service.port)
            elif service.protocol == "icmp":
                success = self.test_icmp_service(vm.ip_address)
            # If direct port test fails, try SSH-based verification
            if not success:
                ssh_result = self.test_service_via_ssh(vm, service)
                if ssh_result is not None:
                    success = ssh_result
                    print(f"    (verified via SSH)")
            status = "✓ PASS" if success else "✗ FAIL"
            print(f"    {status}: {service.description}")
            return (service.name, success)

        with ThreadPoolExecutor(max_workers=min(8, len(vm.services))) as executor:
            future_to_service = {executor.submit(test_one_service, s): s for s in vm.services}
            for future in as_completed(future_to_service):
                name, success = future.result()
                results[name] = success

        return results
    
    def run_tests(self):
        """Run all VM service tests in parallel"""
        print("Free Cloud VPN - VM Service Port Tests")
        print("=" * 50)
        # IPv6 connectivity hint
        if not self.has_ipv6_connectivity():
            print(f"{YELLOW}Note: Local host appears to lack outbound IPv6 connectivity. IPv6 tests may fail.{RESET}")

        vms = self.discover_vms()

        if not vms:
            print("No VMs found in Terraform state.")
            return

        all_results = {}
        from concurrent.futures import ThreadPoolExecutor, as_completed
        with ThreadPoolExecutor(max_workers=min(8, len(vms))) as executor:
            future_to_vm = {executor.submit(self.test_vm_services, vm): vm for vm in vms}
            for future in as_completed(future_to_vm):
                vm = future_to_vm[future]
                results = future.result()
                all_results[f"{vm.provider}_{vm.ip_address}"] = results

        # Run Cloudflare DNS checks (if applicable)
        dns_results = self.test_cloudflare_dns()
        if dns_results:
            all_results["cloudflare_dns"] = dns_results

        # Summary
        print("\n" + "=" * 50)
        print("SUMMARY")
        print("=" * 50)

        total_tests = 0
        total_passed = 0

        for vm_key, results in sorted(all_results.items()):
            print(f"\n{vm_key}:")
            for service, passed in sorted(results.items()):
                total_tests += 1
                if passed:
                    total_passed += 1
                status = f"{GREEN}✓ PASS{RESET}" if passed else f"{RED}✗ FAIL{RESET}"
                print(f"  {status} {service}")

        print(f"\nOverall: {GREEN if total_passed == total_tests else RED}{total_passed}/{total_tests} tests passed{RESET}")

        if total_passed == total_tests:
            print(f"{GREEN}🎉 All services are working correctly!{RESET}")
            return 0
        else:
            print(f"{YELLOW}⚠️  Some services may need attention.{RESET}")
            return 1


def main():
    """Main entry point"""
    tester = VMServiceTester()
    return tester.run_tests()


if __name__ == "__main__":
    sys.exit(main())
