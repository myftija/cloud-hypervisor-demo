#!/bin/bash

set -euo pipefail

DATA_DIR="output"
DEST="$PWD/snapshot_create_latencies.log"

rm -f "$DEST"

pushd $DATA_DIR > /dev/null

COUNT=$(find . -type f -name "ch-sb*" | sort -V | tail -1 | cut -d '-' -f 2 | cut -f 2 -d 'b')

for i in $(seq 0 "$COUNT")
do
  events_file="ch-sb${i}-events-00"
  
  if [ ! -f "$events_file" ]; then
    echo "File $events_file does not exist" >&2
    continue
  fi

  snapshot_start_ns=$(cat "$events_file" | jq -r 'try (select(type == "object" and has("event") and .event == "snapshotting") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)
  snapshot_finish_ns=$(cat "$events_file" | jq -r 'try (select(type == "object" and has("event") and .event == "snapshotted") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)

  if [ -z "$snapshot_start_ns" ] || [ -z "$snapshot_finish_ns" ]; then
    echo "Failed to find snapshotting and snapshotted events in $events_file" >&2
    continue
  fi

  snapshot_creation_time_ms=$(echo "($snapshot_finish_ns - $snapshot_start_ns) / 1000000" | bc)

  echo "$i snapshot_created $snapshot_creation_time_ms ms" >> "$DEST"
done

popd > /dev/null