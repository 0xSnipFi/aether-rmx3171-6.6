#!/usr/bin/env bash
# AETHER RMX3171 - extract boot/radio-critical blobs from stock firmware.
#
# Usage:
#   scripts/extract_blobs.sh <stock-vendor.img-or-mounted-dir> [stock-root-dir]
#
# The first argument may be a raw/simg2img-converted vendor.img or an already
# mounted vendor directory. The optional second argument may point at a full
# stock dump directory containing partition images such as md1img.img/md1dsp.img.
#
# Output:
#   vendor/realme/RMX3171/proprietary/...  (used by vendor makefiles)
#   aether-rmx3171/firmware/...            (kernel bring-up staging)

set -euo pipefail

SRC="${1:-}"
STOCK_ROOT="${2:-}"
if [ -z "$SRC" ] || { [ ! -f "$SRC" ] && [ ! -d "$SRC" ]; }; then
    echo "Usage: $0 <stock-vendor.img-or-mounted-dir> [stock-root-dir]"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FW_OUT="$REPO_ROOT/aether-rmx3171/firmware"
VENDOR_OUT="$REPO_ROOT/vendor/realme/RMX3171/proprietary"
mkdir -p "$FW_OUT" "$VENDOR_OUT"

MNT=""
cleanup() {
    if [ -n "$MNT" ]; then
        sudo umount "$MNT" 2>/dev/null || true
        rmdir "$MNT" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ -d "$SRC" ]; then
    VENDOR_ROOT="$SRC"
else
    MNT="$(mktemp -d)"
    echo "[1/5] mount $SRC ro"
    sudo mount -o ro,loop "$SRC" "$MNT"
    VENDOR_ROOT="$MNT"
fi

find_first() {
    local rel="$1"
    shift || true
    local base
    for base in "$VENDOR_ROOT" "$STOCK_ROOT"; do
        [ -n "$base" ] || continue
        [ -f "$base/$rel" ] && { printf '%s\n' "$base/$rel"; return 0; }
        [ -f "$base/vendor/$rel" ] && { printf '%s\n' "$base/vendor/$rel"; return 0; }
        [ -f "$base/vendor/firmware/$(basename "$rel")" ] && { printf '%s\n' "$base/vendor/firmware/$(basename "$rel")"; return 0; }
        [ -f "$base/$(basename "$rel")" ] && { printf '%s\n' "$base/$(basename "$rel")"; return 0; }
    done
    return 1
}

copy_to_vendor_tree() {
    local rel="$1"
    local src
    if src="$(find_first "$rel")"; then
        mkdir -p "$VENDOR_OUT/$(dirname "$rel")"
        cp -v "$src" "$VENDOR_OUT/$rel"
        case "$rel" in
            vendor/firmware/*|firmware/*|md1*.img)
                cp -v "$src" "$FW_OUT/$(basename "$rel")"
                ;;
        esac
    else
        echo "MISSING in stock: $rel"
    fi
}

echo "[2/5] connsys firmware"
for f in \
    vendor/firmware/WIFI_RAM_CODE_soc1_0_1a_1.bin \
    vendor/firmware/soc1_0_ram_wifi_1a_1_hdr.bin \
    vendor/firmware/soc1_0_ram_bt_1a_1_hdr.bin \
    vendor/firmware/soc1_0_ram_mcu_1a_1_hdr.bin \
    vendor/firmware/soc1_0_patch_mcu_1a_1_hdr.bin; do
    copy_to_vendor_tree "$f"
done

echo "[3/5] modem firmware - do not skip"
for f in \
    vendor/firmware/md1img.img \
    vendor/firmware/md1dsp.img; do
    copy_to_vendor_tree "$f"
done

echo "[4/5] radio/RIL/IMS userspace"
for f in \
    vendor/bin/hw/mtkfusionrild \
    vendor/bin/volte_imsm_93 \
    vendor/etc/init/mtkrild.rc \
    vendor/etc/init/init.volte_imsm_93.rc \
    vendor/etc/vintf/manifest/oplus_appradio_device_manifest.xml \
    vendor/etc/vintf/manifest/oplus_radio_device_manifest.xml \
    vendor/etc/apdb/APDB_MT6768_S01__W2044 \
    vendor/etc/apdb/APDB_MT6768_S01__W2044_ENUM \
    vendor/lib/libmtkrillog.so \
    vendor/lib/librilmtk.so \
    vendor/lib/libipsec_ims_shr.so \
    vendor/lib64/libmtk-ril.so \
    vendor/lib64/librilmtk.so \
    vendor/lib64/libmtkrillog.so \
    vendor/lib64/libmtkrilutils.so \
    vendor/lib64/librilfusion.so \
    vendor/lib64/libgwsd-ril.so \
    vendor/lib64/libipsec_ims_shr.so \
    vendor/lib64/vendor.mediatek.hardware.mtkradioex@2.0.so \
    system_ext/lib/vendor.mediatek.hardware.mtkradioex@1.0.so \
    system_ext/priv-app/OppoSimSettings/OppoSimSettings.apk \
    system_ext/lib64/vendor.mediatek.hardware.modemdbfilter@1.0.so \
    system_ext/lib64/vendor.mediatek.hardware.mtkradioex@1.0.so \
    odm/framework/vendor.oplus.hardware.appradio-V1.0-java.jar \
    odm/framework/vendor.oplus.hardware.ims-V1.0-java.jar \
    odm/framework/vendor.oplus.hardware.radio-V1.0-java.jar \
    odm/lib/vendor.oplus.hardware.appradio@1.0.so \
    odm/lib/vendor.oplus.hardware.ims@1.0.so \
    odm/lib/vendor.oplus.hardware.radio@1.0.so \
    odm/lib64/vendor.oplus.hardware.appradio@1.0.so \
    odm/lib64/vendor.oplus.hardware.ims@1.0.so \
    odm/lib64/vendor.oplus.hardware.radio@1.0.so; do
    copy_to_vendor_tree "$f"
done

echo "[5/5] NV calibration hints"
for n in "$VENDOR_ROOT"/nvdata/nvram_config_*.bin "$VENDOR_ROOT"/../nvdata/nvram_config_*.bin; do
    [ -f "$n" ] || continue
    mkdir -p "$VENDOR_OUT/vendor/nvdata"
    cp -v "$n" "$VENDOR_OUT/vendor/nvdata/"
    cp -v "$n" "$FW_OUT/"
done

echo
echo "[+] extracted vendor blobs to: $VENDOR_OUT"
echo "[+] staged firmware to:       $FW_OUT"
