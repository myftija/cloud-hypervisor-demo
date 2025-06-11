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
  --kernel "${KERNEL}" \
  --cmdline "${CMDLINE}" \
  --disk path=${RO_DRIVE},readonly=true \
  --net "tap=${TAP_DEV},mac=${MAC},ip=${CH_IP},mask=${MASK}" \
  --cpus boot=1 \
  --memory size=128M \
  --serial file=${LOGFILE} \
  --log-file ${LOGFILE} >> "$LOGFILE" &