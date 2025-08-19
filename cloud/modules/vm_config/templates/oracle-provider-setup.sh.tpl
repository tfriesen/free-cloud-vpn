#!/bin/bash
# Oracle Cloud provider-specific startup steps
set -euo pipefail

echo "[oracle] Running provider-specific startup steps"

# Allocate ~21% of RAM in tmpfs (/dev/shm) to reduce idle reclamation
mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
# Compute allocation in MiB: floor((mem_kb * 21 / 100) / 1024)
alloc_mib=$(( (mem_kb * 21 / 100) / 1024 ))
if [ "$alloc_mib" -lt 1 ]; then
  alloc_mib=1
fi

path="/dev/shm/oci-keepalive.bin"
rm -f "$path"
# Use nice to minimize impact; writing zeros ensures actual tmpfs allocation
nice -n 19 dd if=/dev/zero of="$path" bs=1M count="$alloc_mib" status=none conv=fsync
chmod 600 "$path"

echo "[oracle] Allocated ${alloc_mib} MiB at ${path} (~21% of RAM)"
