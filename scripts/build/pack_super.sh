#!/usr/bin/env bash
# Pack a stock-GPT RMX3171 Android 16 super.img.
#
# This creates logical partitions inside the existing physical super
# partition. It does not modify PGPT/SGPT and does not create physical
# vendor_boot/init_boot/dlkm partitions.
#
# Usage:
#   scripts/build/pack_super.sh <image-dir> [output-super.img]
#
# Expected input images when available:
#   system.img vendor.img product.img system_ext.img odm.img
#   vendor_dlkm.img system_dlkm.img

set -euo pipefail

IMG_DIR="${1:-out/target/product/RMX3171}"
OUT_IMG="${2:-$IMG_DIR/super.img}"

SUPER_SIZE="${AETHER_SUPER_SIZE:-6685720576}"
GROUP_SIZE="${AETHER_SUPER_GROUP_SIZE:-6681526272}"
METADATA_SIZE="${AETHER_SUPER_METADATA_SIZE:-65536}"
METADATA_SLOTS="${AETHER_SUPER_METADATA_SLOTS:-2}"

if ! command -v lpmake >/dev/null; then
    echo "[!] lpmake missing; run from an AOSP build env with lpmake in PATH"
    exit 1
fi

if [ ! -d "$IMG_DIR" ]; then
    echo "[!] image dir not found: $IMG_DIR"
    exit 1
fi

args=(
    --metadata-size "$METADATA_SIZE"
    --metadata-slots "$METADATA_SLOTS"
    --super-name super
    --device "super:${SUPER_SIZE}"
    --group "main:${GROUP_SIZE}"
    --sparse
    --output "$OUT_IMG"
)

add_partition() {
    local name="$1"
    local img="$IMG_DIR/${name}.img"
    [ -f "$img" ] || return 0
    local size
    size="$(stat -c %s "$img")"
    args+=(--partition "${name}:readonly:${size}:main")
    args+=(--image "${name}=${img}")
    echo "  add ${name}.img (${size} bytes)"
}

echo "[*] packing RMX3171 stock-GPT super.img"
echo "    input:  $IMG_DIR"
echo "    output: $OUT_IMG"

for p in system vendor product system_ext odm vendor_dlkm system_dlkm; do
    add_partition "$p"
done

lpmake "${args[@]}"

echo "[+] wrote $OUT_IMG"

