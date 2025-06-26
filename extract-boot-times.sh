#!/bin/bash

set -euo pipefail

DATA_DIR="output"
BOOT_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/boot.log"
PING_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/boot_to_network_ready_ping_probe.log"
TCP22_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/boot_to_network_ready_tcp22_probe.log"

mkdir -p $PWD/${BENCHMARK_DIR:-benchmarks}/raw

# Clean up existing output files
rm -f "$BOOT_DEST" "$PING_DEST" "$TCP22_DEST"

pushd $DATA_DIR > /dev/null

COUNT=$(find . -type f -name "ch-sb*" | sort -V | tail -1 | cut -d '-' -f 2 | cut -f 2 -d 'b')

echo "Processing $((COUNT + 1)) log files..."

for i in $(seq 0 "$COUNT")
do
  log_file="ch-sb${i}-log"
  
  if [ ! -f "$log_file" ]; then
    echo "File $log_file does not exist" >&2
    continue
  fi

  echo "Processing $log_file..."

  # Extract boot times (from extract-times.sh)
  kernel_start_line=$(grep "Debug I/O port: Kernel code 0x40" "$log_file" 2>/dev/null || echo "")
  user_start_line=$(grep "Debug I/O port: Kernel code 0x41" "$log_file" 2>/dev/null || echo "")
  
  if [ -n "$kernel_start_line" ] && [ -n "$user_start_line" ]; then
    kernel_time=$(echo "$kernel_start_line" | awk '{print $(NF-1)}')
    user_time=$(echo "$user_start_line" | awk '{print $(NF-1)}')
    
    if [ -n "$kernel_time" ] && [ -n "$user_time" ]; then
      boot_time_seconds=$(echo "$user_time - $kernel_time" | bc)
      boot_time_ms=$(echo "scale=0; ($boot_time_seconds * 1000) / 1" | bc)
      echo "$i boot $boot_time_ms ms" >> "$BOOT_DEST"
    else
      echo "Failed to extract boot time from $log_file" >&2
    fi
  else
    echo "Failed to find boot markers (0x40 and 0x41) in $log_file" >&2
  fi

  boot_to_network_ready_ping_ms=$(cat "$log_file" | grep "BOOT_TO_NETWORK_READY_PING_MS" | head -1 | awk '{print $2}')

  if [ -n "$boot_to_network_ready_ping_ms" ]; then
    echo "$i boot_to_network_ready $boot_to_network_ready_ping_ms ms" >> "$PING_DEST"
  else
    echo "Failed to find boot to network ready ping event in $log_file" >&2
  fi

  # Extract boot-to-network-ready times with TCP22 probe (from extract-boot-to-network-ready-tcp22-times.sh)
  boot_to_network_ready_tcp22_ms=$(cat "$log_file" | grep "BOOT_TO_NETWORK_READY_TCP22_MS" | head -1 | awk '{print $2}')

  if [ -n "$boot_to_network_ready_tcp22_ms" ]; then
    echo "$i boot_to_network_ready_tcp22 $boot_to_network_ready_tcp22_ms ms" >> "$TCP22_DEST"
  else
    echo "Failed to find boot to network ready TCP22 event in $log_file" >&2
  fi
done

popd > /dev/null

echo "Extraction complete!"
echo "Results written to:"
echo "  - Boot times: $BOOT_DEST"
echo "  - Boot-to-network-ready (ping): $PING_DEST"  
echo "  - Boot-to-network-ready (TCP22): $TCP22_DEST" 