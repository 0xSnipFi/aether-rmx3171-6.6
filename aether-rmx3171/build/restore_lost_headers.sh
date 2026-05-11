#!/usr/bin/env bash
# Restore UAPI + kernel headers lost by NTFS case-collision when copying
# Samsung 6.6 from /mnt/e to ext4.
#
# Source: upstream Linux 6.6.50 tarball extracted to /tmp/linux-6.6.50/.
# Destination: ~/aether-rmx3171-6.6/kernel-6.6/

set -e
SRC=/tmp/linux-6.6.50
DST=~/aether-rmx3171-6.6/kernel-6.6
if [ ! -d "$SRC" ]; then
    echo "[!] Expected $SRC. Run:"
    echo "    cd /tmp && curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.50.tar.xz"
    echo "    tar -xJf linux-6.6.50.tar.xz"
    exit 1
fi

restored=0
total=0

# Compare every file in upstream src vs our dst. If file missing in dst, copy.
while IFS= read -r -d '' src; do
    total=$((total+1))
    rel="${src#$SRC/}"
    dst="$DST/$rel"
    if [ ! -e "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
        restored=$((restored+1))
    fi
done < <(find "$SRC/include/uapi" "$SRC/include/linux" "$SRC/include/net" \
              "$SRC/scripts" "$SRC/Documentation/devicetree/bindings" \
              -type f -print0 2>/dev/null)

echo "[+] scanned $total upstream files, restored $restored missing"

# Special: check arch/arm64/include if any missing
while IFS= read -r -d '' src; do
    total=$((total+1))
    rel="${src#$SRC/}"
    dst="$DST/$rel"
    if [ ! -e "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
        restored=$((restored+1))
    fi
done < <(find "$SRC/arch/arm64/include" -type f -print0 2>/dev/null)

echo "[+] including arch/arm64: total $total scanned, $restored restored"
