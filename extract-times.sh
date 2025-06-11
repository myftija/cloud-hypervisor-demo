#!/bin/bash

set -euo pipefail

DATA_DIR="output"
DEST="$PWD/data.log"

rm -f "$DEST"

pushd $DATA_DIR > /dev/null

COUNT=$(find . -type f -name "ch-sb*" | sort -V | tail -1 | cut -d '-' -f 2 | cut -f 2 -d 'b')

for i in $(seq 0 "$COUNT")
do
  log_file="ch-sb${i}-log"
  if [ -f "$log_file" ]; then
    # Extract kernel_start (0x40) and user_start (0x41) timestamps
    kernel_start=$(grep "Debug I/O port: Kernel code 0x40" "$log_file" | awk '{print $(NF-1)}')
    user_start=$(grep "Debug I/O port: Kernel code 0x41" "$log_file" | awk '{print $(NF-1)}')
    
    if [ -n "$kernel_start" ] && [ -n "$user_start" ]; then
      boot_time_seconds=$(echo "$user_start - $kernel_start" | bc)
      boot_time_ms=$(echo "$boot_time_seconds * 1000" | bc)
      echo "$i boot $boot_time_ms ms" >> "$DEST"
    fi
  fi
done

popd > /dev/null

