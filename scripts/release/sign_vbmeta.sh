#!/usr/bin/env bash
# AETHER RMX3171 AVB sign helper.
#
# Stock RMX3171 path:
#   boot.img + dtbo.img + super logical partitions
#
# Optional PGPT-remap path:
#   init_boot.img / vendor_boot.img are included only when present.
#
# Usage:
#   scripts/release/sign_vbmeta.sh <out-dir> [key-path]

set -euo pipefail

OUT="${1:-out}"
KEY="${2:-${AETHER_AVB_KEY_PATH:-external/avb/test/data/testkey_rsa2048.pem}}"
ALGO="SHA256_RSA2048"

if ! command -v avbtool >/dev/null; then
    echo "[!] avbtool missing; run from an AOSP build env with avbtool in PATH"
    exit 1
fi

cd "$OUT"

add_hash_footer_if_present() {
    local p="$1"
    [ -f "${p}.img" ] || return 0
    avbtool add_hash_footer \
        --image "${p}.img" \
        --partition_name "$p" \
        --partition_size "$(stat -c %s "${p}.img")" \
        --algorithm "$ALGO" \
        --key "$KEY"
    echo "  signed $p"
}

append_descriptor_if_present() {
    local img="$1"
    local -n arr_ref="$2"
    [ -f "$img" ] || return 0
    arr_ref+=(--include_descriptors_from_image "$img")
}

echo "[1/3] hash partition images"
for p in boot dtbo system product system_ext vendor odm vendor_dlkm system_dlkm init_boot vendor_boot; do
    add_hash_footer_if_present "$p"
done

echo "[2/3] vbmeta_system + vbmeta_vendor chains"
system_desc=()
append_descriptor_if_present system.img system_desc
append_descriptor_if_present system_ext.img system_desc
append_descriptor_if_present product.img system_desc
append_descriptor_if_present system_dlkm.img system_desc

if [ "${#system_desc[@]}" -gt 0 ]; then
    avbtool make_vbmeta_image \
        --output vbmeta_system.img \
        --algorithm "$ALGO" \
        --key "$KEY" \
        "${system_desc[@]}" \
        --rollback_index "$(date +%s)"
    echo "  wrote vbmeta_system.img"
fi

vendor_desc=()
append_descriptor_if_present vendor.img vendor_desc
append_descriptor_if_present odm.img vendor_desc
append_descriptor_if_present vendor_dlkm.img vendor_desc

if [ "${#vendor_desc[@]}" -gt 0 ]; then
    avbtool make_vbmeta_image \
        --output vbmeta_vendor.img \
        --algorithm "$ALGO" \
        --key "$KEY" \
        "${vendor_desc[@]}" \
        --rollback_index "$(date +%s)"
    echo "  wrote vbmeta_vendor.img"
fi

echo "[3/3] vbmeta root"
root_desc=()
append_descriptor_if_present boot.img root_desc
append_descriptor_if_present dtbo.img root_desc
append_descriptor_if_present init_boot.img root_desc
append_descriptor_if_present vendor_boot.img root_desc

chain_args=()
[ -f vbmeta_system.img ] && chain_args+=(--chain_partition vbmeta_system:1:"$KEY")
[ -f vbmeta_vendor.img ] && chain_args+=(--chain_partition vbmeta_vendor:2:"$KEY")

if [ "${#root_desc[@]}" -eq 0 ]; then
    echo "[!] No root AVB images found in $OUT"
    exit 1
fi

avbtool make_vbmeta_image \
    --output vbmeta.img \
    --algorithm "$ALGO" \
    --key "$KEY" \
    "${root_desc[@]}" \
    "${chain_args[@]}"

echo
echo "[+] AVB chain signed. Verify with:"
echo "    avbtool info_image --image vbmeta.img"

