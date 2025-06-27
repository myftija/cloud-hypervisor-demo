#!/bin/bash

set -euo pipefail

./parallel-start-many.sh 0 1000 4
sleep 5
./extract-boot-times.sh

killall cloud-hypervisor && rm -rf output && mkdir output
sleep 5

./parallel-restore-many.sh 0 1000 4
sleep 5
./extract-restore-times.sh

mkdir -p ./benchmarks/plots

gnuplot \
    -e "log_file='./benchmarks/raw/boot.log';" \
    -e "output_file='./benchmarks/plots/00_boot.png';" \
    -e "series_name='VM boot time';" \
    -e "plot_title='Boot times'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/boot_to_network_ready_ping_probe.log';" \
    -e "output_file='./benchmarks/plots/01_boot_to_network_ready_ping.png';" \
    -e "series_name='Boot to network ready (ping)';" \
    -e "plot_title='Boot to Network Ready Times (Ping Probe)'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/boot_to_network_ready_tcp22_probe.log';" \
    -e "output_file='./benchmarks/plots/02_boot_to_network_ready_tcp22.png';" \
    -e "series_name='Boot to network ready (TCP22)';" \
    -e "plot_title='Boot to Network Ready Times (TCP22 Probe)'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/snapshot.log';" \
    -e "output_file='./benchmarks/plots/03_snapshot.png';" \
    -e "series_name='VM snapshot time';" \
    -e "plot_title='Snapshot Creation Times'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/restore.log';" \
    -e "output_file='./benchmarks/plots/04_restore.png';" \
    -e "series_name='VM restore time';" \
    -e "plot_title='Restore Times'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/restore_to_network_ready_ping_probe.log';" \
    -e "output_file='./benchmarks/plots/05_restore_to_network_ready_ping.png';" \
    -e "series_name='Restore to network ready (ping)';" \
    -e "plot_title='Restore to Network Ready Times (Ping Probe)'" \
    plot_distribution.script

gnuplot \
    -e "log_file='./benchmarks/raw/restore_to_network_ready_tcp22_probe.log';" \
    -e "output_file='./benchmarks/plots/06_restore_to_network_ready_tcp22.png';" \
    -e "series_name='Restore to network ready (TCP22)';" \
    -e "plot_title='Restore to Network Ready Times (TCP22 Probe)'" \
    plot_distribution.script