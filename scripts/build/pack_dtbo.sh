#!/usr/bin/env bash
# Pack RMX3171 device-tree overlay into dtbo.img
# Usage: scripts/build/pack_dtbo.sh [OUT_DIR]
#
# Produces: dtbo.img containing mt6768-rmx3171.dtbo
#
# Preferred: `mkdtimg` from AOSP/libufdt. Falls back to the local
# single-overlay packer in scripts/build/mkdtimg_min.py.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$REPO_ROOT/out}"
K="$REPO_ROOT/kernel-6.6"
DM="$REPO_ROOT/device-modules"
A="$REPO_ROOT/aether-rmx3171"
LOCAL_DTS="$A/dts/mt6768-rmx3171.dts"
K_DTS_DIR="$K/arch/arm64/boot/dts/mediatek"
DTS="$K_DTS_DIR/mt6768-rmx3171.dts"
DTBO="$OUT/dtbo.img"

echo "[1/3] Compile DTS → DTB"
mkdir -p "$OUT/dts"

# Stage the board DTS and required Samsung MTK include files before dtc. This
# keeps the script runnable from a fresh checkout instead of depending on a
# previous kernel build side effect.
install -m644 "$LOCAL_DTS" "$DTS"
for inc in mt6768.dts cust_mt6768_touch_720x1600.dtsi cust_mt6768_msdc.dtsi \
           cust_mt6768_camera.dtsi g85_ref_charger.dtsi \
           S96818AA1.dts mt6769v-a05m_common.dtsi; do
    src="$DM/arch/arm64/boot/dts/mediatek/$inc"
    dst="$K_DTS_DIR/$inc"
    if [ -f "$src" ] && [ ! -f "$dst" ]; then
        cp -f "$src" "$dst"
    fi
done

DTC_BIN="${DTC:-dtc}"
if ! command -v "$DTC_BIN" >/dev/null; then
    DTC_BIN="$K/scripts/dtc/dtc"
fi
if [ ! -x "$DTC_BIN" ] && ! command -v "$DTC_BIN" >/dev/null; then
    echo "ERROR: need dtc or a built kernel scripts/dtc/dtc"
    exit 1
fi

CPP_BIN="${CPP:-cpp}"
if ! command -v "$CPP_BIN" >/dev/null; then
    echo "ERROR: need cpp to preprocess DTS #include directives"
    exit 1
fi

CPP_DTS="$OUT/dts/mt6768-rmx3171.pp.dts"
"$CPP_BIN" -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I "$A/dts" \
    -I "$K/include" \
    -I "$K/arch/arm64/boot/dts" \
    -I "$K_DTS_DIR" \
    "$DTS" > "$CPP_DTS"

"$DTC_BIN" -I dts -O dtb -@ -a 4 \
    -i "$A/dts" \
    -i "$K_DTS_DIR" \
    -o "$OUT/dts/mt6768-rmx3171.dtbo" \
    "$CPP_DTS"

echo "[2/3] Verify overlay magic"
od -An -tx1 -N4 "$OUT/dts/mt6768-rmx3171.dtbo"
# should be 'd00dfeed' (DTB magic). Overlays have phandle fixups embedded.

echo "[3/3] Pack into dtbo.img"
if command -v mkdtimg >/dev/null; then
    mkdtimg create "$DTBO" --page_size=2048 "$OUT/dts/mt6768-rmx3171.dtbo"
elif [ -f "${ANDROID_BUILD_TOP:-}/system/libufdt/utils/src/mkdtboimg.py" ]; then
    python3 "$ANDROID_BUILD_TOP/system/libufdt/utils/src/mkdtboimg.py" create \
        "$DTBO" --page_size=2048 "$OUT/dts/mt6768-rmx3171.dtbo"
else
    python3 "$REPO_ROOT/scripts/build/mkdtimg_min.py" \
        "$DTBO" "$OUT/dts/mt6768-rmx3171.dtbo" --page-size 2048
fi

ls -lh "$DTBO"
echo "[+] dtbo.img ready at $DTBO"
echo "    Flash with: fastboot flash dtbo $DTBO"
