#!/usr/bin/env bash
# AETHER RMX3171 — extract boot-critical blobs from stock vendor.img.
#
# Usage: scripts/extract_blobs.sh <stock-vendor.img>
#
# Pulls firmware files needed for WiFi/BT/FM/GPS/audio bring-up into
# aether-rmx3171/firmware/ (gitignored). See docs/VENDOR_BLOBS.md.

set -euo pipefail

VND="${1:-}"
if [ -z "$VND" ] || [ ! -f "$VND" ]; then
    echo "Usage: $0 <path-to-stock-vendor.img>"
    echo "       (extract from RMX3171_*.ozip via oppo-decrypt + simg2img)"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/aether-rmx3171/firmware"
mkdir -p "$OUT"

MNT="$(mktemp -d)"
trap 'sudo umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null || true' EXIT

echo "[1/4] mount $VND ro"
sudo mount -o ro,loop "$VND" "$MNT"

echo "[2/4] firmware (boot-critical)"
declare -a CRITICAL=(
    "firmware/WIFI_RAM_CODE_MT6768.bin"
    "firmware/WIFI_NVRAM_MT6768.bin"
    "firmware/BT_RAM_CODE_MT6631.bin"
    "firmware/GPS_FW_MT6631.bin"
    "firmware/mt6358-codec.bin"
)
for f in "${CRITICAL[@]}"; do
    src="$MNT/$f"
    if [ -f "$src" ]; then
        cp -v "$src" "$OUT/"
    else
        # alt path search
        alt=$(find "$MNT/firmware" -name "$(basename "$f")" 2>/dev/null | head -1)
        if [ -n "$alt" ]; then
            cp -v "$alt" "$OUT/"
        else
            echo "MISSING in stock: $f"
        fi
    fi
done

echo "[3/4] NV calibration"
for n in "$MNT"/nvdata/nvram_config_*.bin; do
    [ -f "$n" ] && cp -v "$n" "$OUT/"
done

echo "[4/4] audio HAL data"
for a in "$MNT"/etc/audio_param.xml \
         "$MNT"/etc/dirac/diracmobile.config \
         "$MNT"/etc/dirac/diracvdd.bin; do
    [ -f "$a" ] && cp -v "$a" "$OUT/"
done

echo
echo "[+] firmware extracted to: $OUT"
ls -lh "$OUT"
