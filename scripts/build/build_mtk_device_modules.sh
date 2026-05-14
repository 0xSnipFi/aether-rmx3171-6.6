#!/usr/bin/env bash
# Build selected MediaTek out-of-tree device modules needed by RMX3171.
#
# This is intentionally narrow. We only build module groups that have been
# compile-proven against the current 6.6 AETHER kernel and are needed for
# daily-driver bring-up.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
K="${REPO_ROOT}/kernel-6.6"
OUT="${REPO_ROOT}/out"
DM="${REPO_ROOT}/device-modules"

CC="${CC:-clang}"
LD="${LD:-ld.lld}"
AR="${AR:-llvm-ar}"
NM="${NM:-llvm-nm}"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CROSS32="${CROSS_COMPILE_COMPAT:-arm-linux-gnueabi-}"

# Camera ISP3 is still hardware-probe candidate code, but production A16
# packages should include it so physical RMX3171 tests can exercise the stack.
# Set AETHER_BUILD_CAMERA_EXPERIMENTAL=0 to build modem-only artifacts.
AETHER_BUILD_CAMERA_EXPERIMENTAL="${AETHER_BUILD_CAMERA_EXPERIMENTAL:-1}"

COMMON_MAKE=(
    -C "$K"
    O="$OUT"
    ARCH=arm64
    CC="$CC"
    LD="$LD"
    AR="$AR"
    NM="$NM"
    OBJCOPY="$OBJCOPY"
    CROSS_COMPILE="$CROSS"
    CROSS_COMPILE_COMPAT="$CROSS32"
)

COMMON_CFG=(
    DEVICE_MODULES_PATH="$DM"
    CONFIG_MTK_CCCI_DEVICES=y
    CONFIG_MTK_NET_RPS=m
    CONFIG_MTK_NET_CCMNI=m
    CONFIG_MTK_ECCCI_DRIVER=m
    CONFIG_MTK_ECCCI_CLDMA=m
    CONFIG_MTK_ECCCI_CCIF=m
    CONFIG_MTK_SRIL_SUPPORT=y
    CONFIG_MTK_SECURITY_SW_SUPPORT=n
    EXTRA_CFLAGS="-I$DM/include -DCONFIG_MTK_SRIL_SUPPORT"
)

build_mod_dir() {
    local dir="$1"
    shift
    make "${COMMON_MAKE[@]}" M="$dir" "${COMMON_CFG[@]}" "$@" modules
}

echo "[*] Building MTK modem support modules..."

build_mod_dir "$DM/drivers/misc/mediatek/rps"
build_mod_dir "$DM/drivers/misc/mediatek/ccci_util"
build_mod_dir "$DM/drivers/misc/mediatek/ccmni" \
    KBUILD_EXTRA_SYMBOLS="$DM/drivers/misc/mediatek/rps/Module.symvers"

cat \
    "$DM/drivers/misc/mediatek/ccci_util/Module.symvers" \
    "$DM/drivers/misc/mediatek/ccmni/Module.symvers" \
    "$DM/drivers/misc/mediatek/rps/Module.symvers" \
    > "$OUT/aether_eccci_extra.symvers"

build_mod_dir "$DM/drivers/misc/mediatek/eccci" \
    KBUILD_EXTRA_SYMBOLS="$OUT/aether_eccci_extra.symvers"

find \
    "$DM/drivers/misc/mediatek/rps" \
    "$DM/drivers/misc/mediatek/ccci_util" \
    "$DM/drivers/misc/mediatek/ccmni" \
    "$DM/drivers/misc/mediatek/eccci" \
    -name '*.ko' -print | sort > "$OUT/aether-external-modules.txt"

if [ "$AETHER_BUILD_CAMERA_EXPERIMENTAL" = "1" ]; then
    echo "[*] Building experimental MTK ISP3 camera provider modules..."
    bash "$REPO_ROOT/scripts/build/build_mtk_camera_modules_experimental.sh"
    if [ -f "$OUT/aether-camera-experimental-modules.txt" ]; then
        cat "$OUT/aether-camera-experimental-modules.txt" >> "$OUT/aether-external-modules.txt"
        sort -u "$OUT/aether-external-modules.txt" -o "$OUT/aether-external-modules.txt"
    fi
fi

echo "[+] External MTK modules: $(wc -l < "$OUT/aether-external-modules.txt")"
