#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEST_RES="$SCRIPT_DIR/../resources"
S3_BUCKET="spec.ccfc.min"
CH_VERSION="v46.0"

ensure_cloud_hypervisor() {
    file_path="$TEST_RES/cloud-hypervisor"

    wget -q https://github.com/cloud-hypervisor/cloud-hypervisor/releases/download/$CH_VERSION/cloud-hypervisor-static -O "$file_path"
    chmod +x "$file_path"

    echo "Saved cloud-hypervisor at $file_path"
}

ensure_kernel() {
    file_path="$TEST_RES/vmlinux"
    kv="4.14"
    wget -q "https://s3.amazonaws.com/$S3_BUCKET/ci-artifacts/kernels/$TARGET/vmlinux-$kv.bin" -O "$file_path"
    echo "Saved kernel at $file_path..."
}

ensure_rootfs() {
    file_path="$TEST_RES/rootfs.ext4"
    key_path="$TEST_RES/rootfs.id_rsa"
    wget -q "https://s3.amazonaws.com/$S3_BUCKET/img/alpine_demo/fsfiles/xenial.rootfs.ext4" -O "$file_path"
    wget -q "https://s3.amazonaws.com/$S3_BUCKET/img/alpine_demo/fsfiles/xenial.rootfs.id_rsa" -O "$key_path"
    chmod 400 "$key_path"
    echo "Saved rootfs and ssh key at $file_path and $key_path..."
}

mkdir -p "$TEST_RES"

ensure_cloud_hypervisor
ensure_kernel
ensure_rootfs
