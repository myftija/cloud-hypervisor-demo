#!/bin/bash

set -euo pipefail

DATA_DIR="output"
DEST="$PWD/restore_latencies.log"

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

  restored_time_ms=$(cat "$log_file" | jq -r 'try (select(type == "object" and has("event") and .event == "restored") | ((.timestamp.secs * 1000 + .timestamp.nanos / 1000000) | floor)) // empty' 2>/dev/null | head -n 1)

  if [ -z "$restored_time_ms" ]; then
    echo "Failed to find restored event in $log_file" >&2
    continue
  fi

  echo "$i restored $restored_time_ms ms" >> "$DEST"
done

popd > /dev/null