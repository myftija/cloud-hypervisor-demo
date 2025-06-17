#!/bin/bash
set -euo pipefail

source ./start-ch.sh # avoid forking to enable referencing the declared variables, e.g., SB_ID, API_SOCKET, etc...
sleep 1

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

"${CH_BINARY}" \
  --restore source_url=file://${SNAPSHOT_DIR} \
  --event-monitor path=${LOGFILE} >> "$LOGFILE" &