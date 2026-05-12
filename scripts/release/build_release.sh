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
bash "$REPO_ROOT/scripts/build/pack_dtbo.sh" "$OUT" || \
    echo "WARN: dtbo build failed (non-fatal, can flash without)"

# ============================================================
# 3. Stage modules into AnyKernel3
# ============================================================
echo "[3/6] Stage modules into AnyKernel3"
AK3="$REPO_ROOT/AnyKernel3"
[ -d "$AK3" ] || git clone https://github.com/osm0sis/AnyKernel3 "$AK3"
mkdir -p "$AK3/modules/vendor_dlkm"
find "$OUT" -name "*.ko" -exec cp {} "$AK3/modules/vendor_dlkm/" \;
cp "$OUT/arch/arm64/boot/Image.gz-dtb" "$AK3/Image.gz-dtb"
cp "$REPO_ROOT/aether-rmx3171/modules/vendor_boot.modules.load" \
   "$AK3/modules/vendor_boot.modules.load"
cp "$REPO_ROOT/aether-rmx3171/modules/vendor_dlkm.modules.load" \
   "$AK3/modules/vendor_dlkm.modules.load"

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

## Honest hardware status

See [docs/MISSING.md](../docs/MISSING.md) — only WiFi + BT + KSU + NetHunter
confirmed working. Display/audio/camera/charging require P0–P1 items.

## Flash
\`\`\`
fastboot flash boot $ZIP_NAME   # not yet, this is .zip — use recovery
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
