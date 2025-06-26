#!/bin/bash

set -euo pipefail

mkdir -p $PWD/${BENCHMARK_DIR:-benchmarks}/raw

DATA_DIR="output"
SNAPSHOT_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/snapshot.log"
RESTORE_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/restore.log"
NETWORK_PING_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/restore_to_network_ready_ping_probe.log"
NETWORK_TCP22_DEST="$PWD/${BENCHMARK_DIR:-benchmarks}/raw/restore_to_network_ready_tcp22_probe.log"

# Clean up previous output files
rm -f "$SNAPSHOT_DEST" "$RESTORE_DEST" "$NETWORK_PING_DEST" "$NETWORK_TCP22_DEST"

pushd $DATA_DIR > /dev/null

COUNT=$(find . -type f -name "ch-sb*" | sort -V | tail -1 | cut -d '-' -f 2 | cut -f 2 -d 'b')

echo "Processing $((COUNT + 1)) log files..."

for i in $(seq 0 "$COUNT")
do
  # Extract snapshot creation times
  events_file_00="ch-sb${i}-events-00"
  if [ -f "$events_file_00" ]; then
    echo "Processing $events_file_00..."
    
    snapshot_start_ns=$(cat "$events_file_00" | jq -r 'try (select(type == "object" and has("event") and .event == "snapshotting") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)
    snapshot_finish_ns=$(cat "$events_file_00" | jq -r 'try (select(type == "object" and has("event") and .event == "snapshotted") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)

    if [ -n "$snapshot_start_ns" ] && [ -n "$snapshot_finish_ns" ]; then
      snapshot_creation_time_ms=$(echo "($snapshot_finish_ns - $snapshot_start_ns) / 1000000" | bc)
      echo "$i snapshot_created $snapshot_creation_time_ms ms" >> "$SNAPSHOT_DEST"
    else
      echo "Failed to find snapshotting and snapshotted events in $events_file_00" >&2
    fi
  else
    echo "File $events_file_00 does not exist" >&2
  fi

  # Extract restore times
  events_file_01="ch-sb${i}-events-01"
  if [ -f "$events_file_01" ]; then
    echo "Processing $events_file_01..."
    
    restore_start_ns=$(cat "$events_file_01" | jq -r 'try (select(type == "object" and has("event") and .event == "restoring") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)
    restore_finish_ns=$(cat "$events_file_01" | jq -r 'try (select(type == "object" and has("event") and .event == "restored") | (.timestamp.secs * 1000000000 + .timestamp.nanos)) // empty' 2>/dev/null | head -n 1)

    if [ -n "$restore_start_ns" ] && [ -n "$restore_finish_ns" ]; then
      restore_time_ms=$(echo "($restore_finish_ns - $restore_start_ns) / 1000000" | bc)
      echo "$i restored $restore_time_ms ms" >> "$RESTORE_DEST"
    else
      echo "Failed to find restoring and restored events in $events_file_01" >&2
    fi
  else
    echo "File $events_file_01 does not exist" >&2
  fi

  # Extract network ready times (ping and TCP22)
  log_file="ch-sb${i}-log"
  if [ -f "$log_file" ]; then
    echo "Processing $log_file..."

    # Extract ping network ready time
    restore_to_network_ready_ping_ms=$(cat "$log_file" | grep "RESTORE_TO_NETWORK_READY_PING_MS" | head -1 | awk '{print $2}')
    if [ -n "$restore_to_network_ready_ping_ms" ]; then
      echo "$i restore_to_network_ready $restore_to_network_ready_ping_ms ms" >> "$NETWORK_PING_DEST"
    else
      echo "Failed to find restore to network ready ping event in $log_file" >&2
    fi

    # Extract TCP22 network ready time
    restore_to_network_ready_tcp22_ms=$(cat "$log_file" | grep "RESTORE_TO_NETWORK_READY_TCP22_MS" | head -1 | awk '{print $2}')
    if [ -n "$restore_to_network_ready_tcp22_ms" ]; then
      echo "$i restore_to_network_ready_tcp22 $restore_to_network_ready_tcp22_ms ms" >> "$NETWORK_TCP22_DEST"
    else
      echo "Failed to find restore to network ready TCP22 event in $log_file" >&2
    fi
  else
    echo "File $log_file does not exist" >&2
  fi
done

popd > /dev/null

echo "Extraction complete!"
echo "Results written to:"
echo "  - Snapshot times: $SNAPSHOT_DEST"
echo "  - Restore times: $RESTORE_DEST"
echo "  - Restore-to-network-ready (ping): $NETWORK_PING_DEST"
echo "  - Restore-to-network-ready (TCP22): $NETWORK_TCP22_DEST" 