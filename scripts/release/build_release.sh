#!/usr/bin/env bash
# AETHER RMX3171 6.6 — end-to-end release pipeline
# Produces: AETHER_RMX3171_6.6_MT6768-<DATE>v<N>.zip + dtbo.img + SHA256.txt
#
# Usage: scripts/release/build_release.sh <version-tag>
# Example: scripts/release/build_release.sh v5

set -euo pipefail

TAG="${1:-test}"
DATE="$(date +%Y%m%d)"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$REPO_ROOT/out"
REL="$REPO_ROOT/releases"

mkdir -p "$REL"

export AETHER_BUILD_CAMERA_EXPERIMENTAL="${AETHER_BUILD_CAMERA_EXPERIMENTAL:-1}"
export AETHER_BOOT_HEADER_VERSION="${AETHER_BOOT_HEADER_VERSION:-2}"
echo "[layout] RMX3171 stock GPT, boot header v${AETHER_BOOT_HEADER_VERSION}, dtbo partition, logical dlkm in super"
echo "[camera] AETHER_BUILD_CAMERA_EXPERIMENTAL=$AETHER_BUILD_CAMERA_EXPERIMENTAL"

echo "=== AETHER 6.6 release pipeline — $DATE $TAG ==="

# ============================================================
# 1. Kernel build
# ============================================================
echo "[1/6] Kernel build"
bash "$REPO_ROOT/aether-rmx3171/build/build_aether_6_6.sh"
[ -f "$OUT/arch/arm64/boot/Image.gz-dtb" ] || {
    echo "FAIL: Image.gz-dtb not produced"
    exit 1
}

# ============================================================
# 2. dtbo.img
# ============================================================
echo "[2/6] dtbo build"
bash "$REPO_ROOT/scripts/build/pack_dtbo.sh" "$OUT"
[ -f "$OUT/dtbo.img" ] || {
    echo "FAIL: dtbo.img not produced"
    exit 1
}

# ============================================================
# 3. Stage modules into AnyKernel3
# ============================================================
echo "[3/6] Stage modules into AnyKernel3"
AK3="$REPO_ROOT/AnyKernel3"
[ -d "$AK3" ] || git clone https://github.com/osm0sis/AnyKernel3 "$AK3"
cp "$REPO_ROOT/scripts/release/anykernel-aether.sh" "$AK3/anykernel.sh"
rm -rf "$AK3/modules"
mkdir -p "$AK3/modules/vendor_dlkm" "$AK3/modules/vendor_boot" "$AK3/modules/system_dlkm"

BUILT_MODULES="$OUT/aether-built-modules.txt"
if [ -f "$OUT/modules.order" ]; then
    sed 's/\.o$/.ko/' "$OUT/modules.order" | xargs -n1 basename > "$BUILT_MODULES"
else
    find "$OUT" -name "*.ko" -printf "%f\n" | sort > "$BUILT_MODULES"
fi
EXTERNAL_MODULES="$OUT/aether-external-modules.txt"
if [ -f "$EXTERNAL_MODULES" ]; then
    while IFS= read -r ext_module; do
        [ -n "$ext_module" ] || continue
        basename "$ext_module"
    done < "$EXTERNAL_MODULES" >> "$BUILT_MODULES"
    sort -u "$BUILT_MODULES" -o "$BUILT_MODULES"
fi

stage_module() {
    local module="$1"
    local dest="$2"
    local src
    src="$(find "$OUT" -name "$module" -print -quit)"
    if [ -z "$src" ] && [ -f "$EXTERNAL_MODULES" ]; then
        while IFS= read -r ext_module; do
            [ "$(basename "$ext_module")" = "$module" ] || continue
            src="$ext_module"
            break
        done < "$EXTERNAL_MODULES"
    fi
    [ -n "$src" ] || return 1
    cp "$src" "$dest/"
}

stage_manifest() {
    local manifest="$1"
    local dest="$2"
    local module
    while IFS= read -r module; do
        case "$module" in
            ""|\#*) continue ;;
        esac
        if ! grep -Fxq "$module" "$BUILT_MODULES"; then
            echo "FAIL: manifest requests missing module: $module"
            exit 1
        fi
        stage_module "$module" "$dest"
    done < "$manifest"
}

stage_manifest "$REPO_ROOT/aether-rmx3171/modules/vendor_boot.modules.load" "$AK3/modules/vendor_boot"
stage_manifest "$REPO_ROOT/aether-rmx3171/modules/vendor_dlkm.modules.load" "$AK3/modules/vendor_dlkm"
stage_manifest "$REPO_ROOT/aether-rmx3171/modules/system_dlkm.modules.load" "$AK3/modules/system_dlkm"

# Keep every built module available in the zip for manual recovery/testing, but
# only the validated manifests above are auto-loaded.
while IFS= read -r module; do
    [ -n "$module" ] || continue
    [ -f "$AK3/modules/vendor_boot/$module" ] && continue
    [ -f "$AK3/modules/system_dlkm/$module" ] && continue
    [ -f "$AK3/modules/vendor_dlkm/$module" ] && continue
    stage_module "$module" "$AK3/modules/vendor_dlkm"
done < "$BUILT_MODULES"

cp "$OUT/arch/arm64/boot/Image.gz-dtb" "$AK3/Image.gz-dtb"
cp "$OUT/dtbo.img" "$AK3/dtbo.img"
cp "$REPO_ROOT/aether-rmx3171/modules/vendor_boot.modules.load" \
   "$AK3/modules/vendor_boot.modules.load"
cp "$REPO_ROOT/aether-rmx3171/modules/vendor_dlkm.modules.load" \
   "$AK3/modules/vendor_dlkm.modules.load"
cp "$REPO_ROOT/aether-rmx3171/modules/system_dlkm.modules.load" \
   "$AK3/modules/system_dlkm.modules.load"

# ============================================================
# 4. Pack AnyKernel zip
# ============================================================
echo "[4/6] Pack AnyKernel3 zip"
ZIP_NAME="AETHER_RMX3171_6.6_MT6768-${DATE}${TAG}.zip"
ZIP_PATH="$REL/$ZIP_NAME"
cd "$AK3"
rm -f "$ZIP_PATH"
zip -r9 "$ZIP_PATH" . -x "*.git*" "*.zip" "README.md"
cd - >/dev/null

# ============================================================
# 5. SHA-256 + size manifest
# ============================================================
echo "[5/6] Manifest"
MANIFEST="$REL/${ZIP_NAME%.zip}.sha256"
cd "$REL"
sha256sum "$ZIP_NAME" > "$MANIFEST"
[ -f "$OUT/dtbo.img" ] && cp "$OUT/dtbo.img" "$REL/" && \
    sha256sum "dtbo.img" >> "$MANIFEST"
cat "$MANIFEST"
cd - >/dev/null

# ============================================================
# 6. Release notes
# ============================================================
echo "[6/6] Release notes"
NOTES="$REL/${ZIP_NAME%.zip}.md"
cat > "$NOTES" <<EOF
# AETHER RMX3171 6.6 — $TAG

Build date: $DATE
Linux base: 6.6.50 (Samsung A055F) + AETHER overlay
MTK symbols in vmlinux: $(grep -c 'mtk\|MT6' "$OUT/System.map" 2>/dev/null || echo 'n/a')
Modules: $(find "$AK3/modules" -name '*.ko' | wc -l) .ko

## Artifacts
- \`$ZIP_NAME\` — AnyKernel3 flashable
- \`dtbo.img\` — overlay device-tree (flash separately)

## SHA-256
\`\`\`
$(cat "$MANIFEST")
\`\`\`

## What changed
(populate from git log since last tag)

## Boot layout

Default target is the real RMX3171 stock GPT path:

- boot header v2
- kernel + ramdisk + DTB in boot.img / AnyKernel repack
- physical dtbo partition
- no physical vendor_boot or init_boot
- vendor_dlkm/system_dlkm are logical partitions for full ROM builds, or
  module folders inside this recovery flashable zip for kernel-only tests

## Honest hardware status

See [docs/MISSING.md](../docs/MISSING.md). This artifact is compile/package
proven, not hardware-proven. Kernel-side Panfrost, ECCCI modem modules, and
optional ISP3 camera modules may be included depending on build flags, but
display/touch/audio/charging/fingerprint/camera/radio still need RMX3171 logs.

## Flash
\`\`\`
adb sideload $ZIP_NAME

# Only when explicitly testing the generated DTBO:
fastboot flash dtbo dtbo.img
\`\`\`

Use TWRP / OrangeFox to sideload the AnyKernel zip.

EOF
echo "[ok] notes at $NOTES"

echo
echo "================================================================="
echo "  Release built: $ZIP_PATH"
echo "  Manifest:      $MANIFEST"
echo "  Notes:         $NOTES"
echo "================================================================="
echo
echo "Next: gh release create $TAG $ZIP_PATH $REL/dtbo.img --notes-file $NOTES"
