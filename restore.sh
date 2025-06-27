#!/bin/bash
set -euo pipefail

SKIP_BOOT_NETWORK_READINESS_CHECK=true
source ./start-ch.sh # avoid forking to enable referencing the declared variables, e.g., SB_ID, API_SOCKET, etc...
sleep 0.5s

SNAPSHOT_DIR="$PWD/output/ch-sb${SB_ID}-snapshot"

curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.pause'

rm -rf "$SNAPSHOT_DIR"
mkdir -p "$SNAPSHOT_DIR"
curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.snapshot' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "destination_url": "file://'"${SNAPSHOT_DIR}"'"
  }'

curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.shutdown'
sleep 0.5s

EVENTS_FILE_01="$PWD/output/ch-sb${SB_ID}-events-01"
rm -f "$EVENTS_FILE_01"
touch "$EVENTS_FILE_01"

rm -f "$API_SOCKET"
restore_call_ts=$(date +%s.%N)
"${CH_BINARY}" \
  --api-socket "${API_SOCKET}" \
  --restore source_url=file://${SNAPSHOT_DIR} \
  --event-monitor path=${EVENTS_FILE_01} >> "$LOGFILE" &

# Wait for API server to start
while [ ! -e "$API_SOCKET" ]; do
    echo "CH $SB_ID still not ready..."
    sleep 0.01s
done

curl --silent --show-error --unix-socket "${API_SOCKET}" -i \
  -X PUT 'http://localhost/api/v1/vm.resume'

# non-blocking network readiness check - ping
{
  max_attempts=600
  attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if ping -c 1 -W 1 "${CH_IP}" >/dev/null 2>&1; then
      end_time=$(date +%s.%N)
      time_diff_sec=$(echo "$end_time - $restore_call_ts" | bc -l)
      time_diff_ms=$(printf "%.0f" $(echo "$time_diff_sec * 1000" | bc -l))
      echo "RESTORE_TO_NETWORK_READY_PING_MS ${time_diff_ms}" >> "${LOGFILE}"
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  if [ $attempt -ge $max_attempts ]; then
    echo "RESTORE_TO_NETWORK_READY_PING_TIMEOUT" >> "${LOGFILE}"
  fi
} &

# non-blocking network readiness check - TCP port 22
{
  max_attempts=600
  attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if nc -z -w 1 "${CH_IP}" 22 >/dev/null 2>&1; then
      end_time=$(date +%s.%N)
      time_diff_sec=$(echo "$end_time - $restore_call_ts" | bc -l)
      time_diff_ms=$(printf "%.0f" $(echo "$time_diff_sec * 1000" | bc -l))
      echo "RESTORE_TO_NETWORK_READY_TCP22_MS ${time_diff_ms}" >> "${LOGFILE}"
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  if [ $attempt -ge $max_attempts ]; then
    echo "RESTORE_TO_NETWORK_READY_TCP22_TIMEOUT" >> "${LOGFILE}"
  fi
} &