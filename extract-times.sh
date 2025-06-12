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
  
  if [ ! -f "$log_file" ]; then
    echo "File $log_file does not exist" >&2
    continue
  fi

  kernel_start_line=$(grep "Debug I/O port: Kernel code 0x40" "$log_file" 2>/dev/null || echo "")
  user_start_line=$(grep "Debug I/O port: Kernel code 0x41" "$log_file" 2>/dev/null || echo "")
  
  if [ -z "$kernel_start_line" ] || [ -z "$user_start_line" ]; then
    echo "Failed to find 0x40 and 0x41 markers in $log_file" >&2
    continue
  fi

  kernel_time=$(echo "$kernel_start_line" | awk '{print $(NF-1)}')
  user_time=$(echo "$user_start_line" | awk '{print $(NF-1)}')
  
  if [ -z "$kernel_time" ] || [ -z "$user_time" ]; then
    echo "Failed to extract time from $log_file" >&2
    continue
  fi

  boot_time_seconds=$(echo "$user_time - $kernel_time" | bc)
  boot_time_ms=$(echo "scale=0; ($boot_time_seconds * 1000) / 1" | bc)
  echo "$i boot $boot_time_ms ms" >> "$DEST"
done

popd > /dev/null