#!/usr/bin/env bash
# AETHER RMX3171 — Linux 6.6.50 build entry point
#
# Bypasses Samsung Kleaf/Bazel — uses plain make + out-of-tree modules via
# Samsung's kernel_device_modules-6.6 path.
#
# Usage:
#   bash aether-rmx3171/build/build_aether_6_6.sh
#
# Env overrides:
#   CC, LD, AR, NM, OBJCOPY (toolchain)
#   JOBS (default: nproc)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K="${ROOT}/kernel-6.6"
DM="${ROOT}/device-modules"
VM="${ROOT}/vendor-modules"
A="${ROOT}/aether-rmx3171"
OUT="${ROOT}/out"
JOBS="${JOBS:-$(nproc)}"

# Toolchain. Samsung's 6.6.50 Android kernel family expects Android clang
# r510928/clang 18+. Community builds may still compile with distro clang, but
# production builds should set AETHER_PRODUCTION_BUILD=1 to reject older clang.
if [ -z "${CC:-}" ]; then
    for candidate in \
        "${ANDROID_CLANG_ROOT:-}/bin" \
        "${CLANG_PREBUILT_DIR:-}/bin" \
        "$ROOT/prebuilts/clang/host/linux-x86/clang-r510928/bin" \
        "$ROOT/prebuilts/clang/host/linux-x86/clang-r522817/bin" \
        "$ROOT/toolchain/clang-r510928/bin" \
        "$ROOT/toolchain/clang-r522817/bin" \
        "/opt/android/clang-r510928/bin" \
        "/opt/android/clang-r522817/bin"; do
        if [ -x "$candidate/clang" ]; then
            export PATH="$candidate:$PATH"
            break
        fi
    done
fi

CC="${CC:-clang}"
LD="${LD:-ld.lld}"
AR="${AR:-llvm-ar}"
NM="${NM:-llvm-nm}"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CROSS32="${CROSS_COMPILE_COMPAT:-arm-linux-gnueabi-}"

echo "[*] AETHER RMX3171 6.6 build"
echo "    kernel:    $K"
echo "    devmod:    $DM"
echo "    vendormod: $VM"
echo "    overlay:   $A"
echo "    out:       $OUT"
echo "    jobs:      $JOBS"
echo "    CC:        $($CC --version | head -1)"
echo "    LD:        $($LD --version | head -1)"
echo

if [ ! -x "$(command -v $CC)" ]; then
    echo "[!] $CC not found"; exit 2
fi

# Toolchain sanity: 6.6.50 wants clang >= 16 ideally. Warn if older.
CLANG_VER=$($CC --version | head -1 | grep -oE 'version [0-9]+' | awk '{print $2}')
if [ -n "$CLANG_VER" ] && [ "$CLANG_VER" -lt 16 ]; then
    echo "[!] Warning: clang $CLANG_VER detected. 6.6.50 expects >= 16; production expects >= 18."
    echo "    Install Android clang-r510928/clang-r522817 or system clang-18."
fi
if [ "${AETHER_PRODUCTION_BUILD:-0}" = "1" ] && { [ -z "$CLANG_VER" ] || [ "$CLANG_VER" -lt 18 ]; }; then
    echo "[!] Refusing production build with $($CC --version | head -1)"
    echo "    Set ANDROID_CLANG_ROOT=/path/to/clang-r510928 or CLANG_PREBUILT_DIR=/path/to/prebuilt."
    exit 2
fi
echo "    production guard: AETHER_PRODUCTION_BUILD=${AETHER_PRODUCTION_BUILD:-0}"

mkdir -p "$OUT"

# ============================================================
# Step 1: stage AETHER overlays into kernel tree
# ============================================================
echo "[*] Staging AETHER overlays..."

# Place our DTS so kernel-6.6 build sees it.
install -m644 "$A/dts/mt6768-rmx3171.dts" \
    "$K/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dts"

# Place our overlay config to be merged onto Samsung a05m_defconfig.
install -m644 "$A/configs/aether_rmx3171_overlay.config" \
    "$K/arch/arm64/configs/aether_rmx3171_overlay.config"

# Expose AETHER RMX3171 slim ports to the kernel build. Keep the source in
# aether-rmx3171/ports so the Samsung/ACK base can be re-staged without losing
# our code, then link it into drivers/aether and hook the top-level Kconfig and
# Makefile idempotently.
AETHER_DRV="$K/drivers/aether"
if [ -L "$AETHER_DRV" ]; then
    ln -sfn "$A/ports" "$AETHER_DRV"
elif [ ! -e "$AETHER_DRV" ]; then
    ln -s "$A/ports" "$AETHER_DRV"
else
    echo "[!] $AETHER_DRV exists and is not a symlink; using it as-is."
fi

DRIVERS_KCONFIG="$K/drivers/Kconfig"
if ! grep -q 'source "drivers/aether/Kconfig"' "$DRIVERS_KCONFIG"; then
    if grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVERS_KCONFIG"; then
        sed -i '/source "drivers\/kernelsu\/Kconfig"/a source "drivers/aether/Kconfig"' "$DRIVERS_KCONFIG"
    else
        sed -i '/^endmenu$/i source "drivers/aether/Kconfig"' "$DRIVERS_KCONFIG"
    fi
fi

DRIVERS_MAKEFILE="$K/drivers/Makefile"
if ! grep -q 'aether/' "$DRIVERS_MAKEFILE"; then
    printf '\n# AETHER RMX3171 board-specific 4.14 -> 6.6 slim ports\nobj-y += aether/\n' >> "$DRIVERS_MAKEFILE"
fi

# Pull Samsung MTK customer includes into kernel-6.6 DTS dir if absent.
for inc in mt6768.dts cust_mt6768_touch_720x1600.dtsi cust_mt6768_msdc.dtsi \
           cust_mt6768_camera.dtsi g85_ref_charger.dtsi \
           S96818AA1.dts mt6769v-a05m_common.dtsi; do
    src="$DM/arch/arm64/boot/dts/mediatek/$inc"
    dst="$K/arch/arm64/boot/dts/mediatek/$inc"
    if [ -f "$src" ] && [ ! -f "$dst" ]; then
        cp -f "$src" "$dst"
    fi
done

# Some MTK out-of-tree drivers require newer SIP service IDs than Samsung's
# trimmed kernel header exposes. Stage the device-modules copy so ECCCI/CCCI
# can compile against the same secure-monitor ABI used by the module source.
MTK_SIP_SRC="$DM/include/linux/soc/mediatek/mtk_sip_svc.h"
MTK_SIP_DST="$K/include/linux/soc/mediatek/mtk_sip_svc.h"
if [ -f "$MTK_SIP_SRC" ]; then
    install -m644 "$MTK_SIP_SRC" "$MTK_SIP_DST"
fi

# Register our DTS in the kernel Makefile if not already.
DTS_MK="$K/arch/arm64/boot/dts/mediatek/Makefile"
if [ -f "$DTS_MK" ] && ! grep -q 'mt6768-rmx3171.dtb' "$DTS_MK"; then
    echo "dtb-\$(CONFIG_ARCH_MEDIATEK) += mt6768-rmx3171.dtb" >> "$DTS_MK"
fi

# ============================================================
# Step 2: build base defconfig (Samsung a05m_defconfig as starting point)
# ============================================================
echo "[*] Generating base config from Samsung mediatek-bazel_defconfig..."
# Use Samsung a05m_defconfig because it's already MT6768-tailored.
cp "$DM/arch/arm64/configs/a05m_defconfig" \
    "$K/arch/arm64/configs/aether_rmx3171_base_defconfig"

make -C "$K" O="$OUT" ARCH=arm64 \
    CC="$CC" LD="$LD" AR="$AR" NM="$NM" OBJCOPY="$OBJCOPY" \
    CROSS_COMPILE="$CROSS" CROSS_COMPILE_COMPAT="$CROSS32" \
    aether_rmx3171_base_defconfig

# ============================================================
# Step 3: merge AETHER overlay on top
# ============================================================
echo "[*] Merging AETHER overlay config..."
"$K/scripts/kconfig/merge_config.sh" -m -O "$OUT" \
    "$OUT/.config" \
    "$A/configs/aether_rmx3171_overlay.config"

make -C "$K" O="$OUT" ARCH=arm64 \
    CC="$CC" LD="$LD" AR="$AR" NM="$NM" OBJCOPY="$OBJCOPY" \
    CROSS_COMPILE="$CROSS" CROSS_COMPILE_COMPAT="$CROSS32" \
    olddefconfig

# Config changes can leave old .ko files in O=out. Remove stale module
# artifacts so release packaging only sees modules from the current config.
echo "[*] Cleaning stale module artifacts..."
find "$OUT" -name '*.ko' -delete
rm -f "$OUT/modules.order"

# ============================================================
# Step 4: build Image.gz-dtb + DTB + modules (in-tree)
# ============================================================
echo "[*] Building kernel image + DTBs..."
make -C "$K" O="$OUT" ARCH=arm64 \
    CC="$CC" LD="$LD" AR="$AR" NM="$NM" OBJCOPY="$OBJCOPY" \
    CROSS_COMPILE="$CROSS" CROSS_COMPILE_COMPAT="$CROSS32" \
    -j"$JOBS" \
    Image.gz mediatek/mt6768-rmx3171.dtb modules

# Build Image.gz-dtb (concat)
cat "$OUT/arch/arm64/boot/Image.gz" \
    "$OUT/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb" \
    > "$OUT/arch/arm64/boot/Image.gz-dtb"

# ============================================================
# Step 5: build out-of-tree MTK device modules
# ============================================================
echo "[*] Building MTK device modules..."
if [ -x "$ROOT/scripts/build/build_mtk_device_modules.sh" ]; then
    bash "$ROOT/scripts/build/build_mtk_device_modules.sh"
else
    echo "[!] scripts/build/build_mtk_device_modules.sh missing; skipping"
fi

echo
echo "[+] Build complete."
ls -la "$OUT/arch/arm64/boot/" | head -20
echo
echo "Artifacts:"
echo "    Image.gz-dtb : $OUT/arch/arm64/boot/Image.gz-dtb"
echo "    DTB          : $OUT/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb"
if [ -f "$OUT/modules.order" ]; then
    echo "    Modules      : $(wc -l < "$OUT/modules.order") current .ko files"
else
    echo "    Modules      : $(find "$OUT" -name '*.ko' 2>/dev/null | wc -l) .ko files"
fi
