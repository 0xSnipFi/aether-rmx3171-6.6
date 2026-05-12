#!/usr/bin/env bash
# Pack RMX3171 device-tree overlay into dtbo.img
# Usage: scripts/build/pack_dtbo.sh [OUT_DIR]
#
# Produces: dtbo.img containing mt6768-rmx3171.dtbo
#
# Required: $ANDROID_BUILD_TOP/system/libufdt/utils/src/mkdtboimg.py
# or `mkdtimg` from android-tools-extra

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$REPO_ROOT/out}"
DTS="$REPO_ROOT/aether-rmx3171/dts/mt6768-rmx3171.dts"
DTBO="$OUT/dtbo.img"

# Check tooling
if ! command -v mkdtimg >/dev/null && \
   [ ! -x "${ANDROID_BUILD_TOP:-}/system/libufdt/utils/src/mkdtboimg.py" ]; then
    echo "ERROR: need mkdtimg (apt install android-sdk-libsparse-utils) or AOSP tree"
    exit 1
fi

echo "[1/3] Compile DTS → DTB"
mkdir -p "$OUT/dts"
dtc -I dts -O dtb -@ -o "$OUT/dts/mt6768-rmx3171.dtbo" "$DTS"

echo "[2/3] Verify overlay magic"
head -c 4 "$OUT/dts/mt6768-rmx3171.dtbo" | xxd | head -1
# should be 'd00dfeed' (DTB magic). Overlays have phandle fixups embedded.

echo "[3/3] Pack into dtbo.img"
if command -v mkdtimg >/dev/null; then
    mkdtimg create "$DTBO" --page_size=2048 "$OUT/dts/mt6768-rmx3171.dtbo"
else
    python3 "$ANDROID_BUILD_TOP/system/libufdt/utils/src/mkdtboimg.py" create \
        "$DTBO" --page_size=2048 "$OUT/dts/mt6768-rmx3171.dtbo"
fi

ls -lh "$DTBO"
echo "[+] dtbo.img ready at $DTBO"
echo "    Flash with: fastboot flash dtbo $DTBO"
