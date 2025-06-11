#!/bin/bash

set -euo pipefail

#Usage 
## sudo ./start.sh 0 100 # Will start VM#0 to VM#99. 

start="${1:-0}"
upperlim="${2:-1}"

for ((i=start; i<upperlim; i++)); do
  ./start-ch.sh "$i" || echo "Could not start Cloud Hypervisor! Check the log file under output/ch-sb$i-log"
done
