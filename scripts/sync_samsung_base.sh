#!/usr/bin/env bash
# AETHER RMX3171 6.6 — sync Samsung A055F kernel base from upstream
#
# Samsung's SM-A055F (Galaxy A05M) uses MT6768 — the same SoC as Realme
# Narzo 30A (RMX3171). We reuse Samsung's open-source kernel as the BSP
# base, then layer RMX3171 overlays on top.
#
# Source: https://opensource.samsung.com — search for "SM-A055F" kernel
#         (Linux 6.6.50 / Android 15 baseline).
#
# This script does NOT redistribute Samsung sources. User must download
# the Samsung kernel tarball manually and point this script at it.
#
# Usage:
#   export SAMSUNG_KERNEL_ROOT=/path/to/SM-A055F_15_Opensource/Kernel
#   bash scripts/sync_samsung_base.sh

set -euo pipefail

if [ -z "${SAMSUNG_KERNEL_ROOT:-}" ]; then
    echo "[!] SAMSUNG_KERNEL_ROOT not set"
    echo "    1. Download Samsung A055F kernel from https://opensource.samsung.com"
    echo "       (search 'SM-A055F', download 'SM-A055F_15_Opensource.zip')"
    echo "    2. Extract and set:"
    echo "       export SAMSUNG_KERNEL_ROOT=/path/to/SM-A055F_15_Opensource/Kernel"
    exit 1
fi

if [ ! -d "$SAMSUNG_KERNEL_ROOT/kernel-6.6" ]; then
    echo "[!] Samsung tree at $SAMSUNG_KERNEL_ROOT does not contain kernel-6.6/"
    exit 2
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "[*] Syncing Samsung kernel-6.6 base to $REPO_ROOT/kernel-6.6/"
rsync -a --info=progress2 "$SAMSUNG_KERNEL_ROOT/kernel-6.6/" "$REPO_ROOT/kernel-6.6/"

echo "[*] Syncing Samsung kernel_device_modules-6.6 (MTK BSP)..."
rsync -a "$SAMSUNG_KERNEL_ROOT/kernel/kernel_device_modules-6.6/" "$REPO_ROOT/device-modules/"

echo "[*] Syncing Samsung vendor/mediatek/kernel_modules (Mali GPU + vendor)..."
rsync -a "$SAMSUNG_KERNEL_ROOT/vendor/" "$REPO_ROOT/vendor-modules/"

echo "[*] Restoring NTFS-lost UAPI headers from upstream Linux 6.6.50..."
if [ ! -d /tmp/linux-6.6.50 ]; then
    cd /tmp
    curl -LSso linux-6.6.50.tar.xz \
        https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.50.tar.xz
    tar -xJf linux-6.6.50.tar.xz
fi
bash "$REPO_ROOT/aether-rmx3171/build/restore_lost_headers.sh"
bash "$REPO_ROOT/aether-rmx3171/build/restore_all_lost.sh" || true

echo
echo "[+] Samsung base + UAPI headers staged. Ready to build:"
echo "    bash aether-rmx3171/build/build_aether_6_6.sh"
