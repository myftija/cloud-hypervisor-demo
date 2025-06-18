#!/bin/bash
set -euo pipefail

SB_ID="${1:-0}"

CH_BINARY="$PWD/resources/cloud-hypervisor"
KERNEL="$PWD/resources/vmlinux"
RO_DRIVE="$PWD/resources/rootfs.ext4"
LOGFILE="$PWD/output/ch-sb${SB_ID}-log"
API_SOCKET="/tmp/ch-sb${SB_ID}.sock"

TAP_DEV="ch-${SB_ID}-tap0"
MASK="255.255.255.252"            # /30
CH_IP=$(printf '169.254.%s.%s' $(((4*SB_ID+1)/256)) $(((4*SB_ID+1)%256)))
TAP_IP=$(printf '169.254.%s.%s' $(((4*SB_ID+2)/256)) $(((4*SB_ID+2)%256)))
MAC=$(printf '02:CC:00:00:%02X:%02X' $((SB_ID/256)) $((SB_ID%256)))

CMDLINE="init=/sbin/boottime_init panic=1 pci=on nomodules reboot=k \
tsc=reliable quiet i8042.nokbd i8042.noaux 8250.nr_uarts=0 ipv6.disable=1 \
ip=${CH_IP}::${TAP_IP}:${MASK}::eth0:off root=/dev/vda ro"

rm -f "$API_SOCKET"
"${CH_BINARY}" \
  --api-socket "${API_SOCKET}" \
  --log-file ${LOGFILE} >> "$LOGFILE" &

curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.create' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "cpus": { "boot_vcpus": 1, "max_vcpus": 1 },
    "memory": { "size": 134217728 },
    "payload": {
      "kernel": "'"${KERNEL}"'",
      "cmdline": "'"${CMDLINE}"'"
    },
    "disks": [
      {
        "path": "'"${RO_DRIVE}"'",
        "readonly": true
      }
    ],
    "net": [
      {
        "tap": "'"${TAP_DEV}"'",
        "mac": "'"${MAC}"'",
        "ip": "'"${CH_IP}"'",
        "mask": "'"${MASK}"'"
      }
    ],
    "serial": {
      "mode": "File",
      "file": "'"${LOGFILE}"'"
    }
  }'

boot_call_ts=$(date +%s.%N)
curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.boot'

# non-blocking network readiness check - ping
{
  max_attempts=600
  attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if ping -c 1 -W 1 "${CH_IP}" >/dev/null 2>&1; then
      end_time=$(date +%s.%N)
      time_diff_sec=$(echo "$end_time - $boot_call_ts" | bc -l)
      time_diff_ms=$(printf "%.0f" $(echo "$time_diff_sec * 1000" | bc -l))
      echo "BOOT_TO_NETWORK_READY_PING_MS ${time_diff_ms}" >> "${LOGFILE}"
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  if [ $attempt -ge $max_attempts ]; then
    echo "BOOT_TO_NETWORK_READY_PING_TIMEOUT" >> "${LOGFILE}"
  fi
} &
