#!/usr/bin/env bash
# AETHER RMX3171 — AVB sign pipeline.
#
# Usage:
#   scripts/release/sign_vbmeta.sh <out-dir> [key-path]
#
# Reads boot.img + vendor_boot.img + init_boot.img + dtbo.img + vendor_dlkm.img
# from <out-dir>, produces vbmeta.img + vbmeta_system.img + vbmeta_vendor.img.

set -euo pipefail

OUT="${1:-out}"
KEY="${2:-external/avb/test/data/testkey_rsa2048.pem}"
ALGO="SHA256_RSA2048"

if ! command -v avbtool >/dev/null; then
    echo "[!] avbtool missing (apt install android-tools-fsutils or AOSP build env)"
    exit 1
fi

cd "$OUT"

echo "[1/3] hash partitions"
for p in boot init_boot vendor_boot dtbo vendor_dlkm system_dlkm; do
    [ -f "${p}.img" ] || continue
    avbtool add_hash_footer \
        --image "${p}.img" \
        --partition_name "$p" \
        --partition_size $(stat -c %s "${p}.img") \
        --algorithm "$ALGO" \
        --key "$KEY"
    echo "  signed $p"
done

echo "[2/3] vbmeta_system + vbmeta_vendor chains"
for chain in system vendor; do
    avbtool make_vbmeta_image \
        --output "vbmeta_${chain}.img" \
        --algorithm "$ALGO" \
        --key "$KEY" \
        --include_descriptors_from_image "${chain}.img" \
        --rollback_index "$(date +%s)" || true
done

echo "[3/3] vbmeta root"
avbtool make_vbmeta_image \
    --output vbmeta.img \
    --algorithm "$ALGO" \
    --key "$KEY" \
    --include_descriptors_from_image boot.img \
    --include_descriptors_from_image init_boot.img \
    --include_descriptors_from_image vendor_boot.img \
    --include_descriptors_from_image dtbo.img \
    --chain_partition vbmeta_system:1:"$KEY" \
    --chain_partition vbmeta_vendor:2:"$KEY"

echo
echo "[+] AVB chain signed. Verify with:"
echo "    avbtool info_image --image vbmeta.img"
