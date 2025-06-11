#!/bin/bash

set -euo pipefail

COUNT=$(find /sys/class/net/* | wc -l)

killall iperf3
killall cloud-hypervisor

for ((i=0; i<COUNT; i++))
do
  ip link del ch-"$i"-tap0 2> /dev/null &
done

rm -rf output/*
rm -rf /tmp/ch-sb*
