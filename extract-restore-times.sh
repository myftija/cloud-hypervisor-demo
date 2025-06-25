#!/bin/bash

set -euo pipefail

DATA_DIR="output"
DEST="$PWD/restore_latencies.log"

rm -f "$DEST"

pushd $DATA_DIR > /dev/null

COUNT=$(find . -type f -name "ch-sb*" | sort -V | tail -1 | cut -d '-' -f 2 | cut -f 2 -d 'b')

for i in $(seq 0 "$COUNT")
do
  events_file="ch-sb${i}-events-01"
  
  if [ ! -f "$events_file" ]; then
    echo "File $events_file does not exist" >&2
    continue
  fi

  restore_start_ns=$(cat "$events_file" | jq -r 'try (select(type == "object" and has("event") and .event == "restoring") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)
  restore_finish_ns=$(cat "$events_file" | jq -r 'try (select(type == "object" and has("event") and .event == "restored") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)

  if [ -z "$restore_start_ns" ] || [ -z "$restore_finish_ns" ]; then
    echo "Failed to find restoring and restored events in $events_file" >&2
    continue
  fi

  restore_time_ms=$(echo "($restore_finish_ns - $restore_start_ns) / 1000000" | bc)

  echo "$i restored $restored_time_ms ms" >> "$DEST"
done

popd > /dev/null