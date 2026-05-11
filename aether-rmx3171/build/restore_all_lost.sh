#!/usr/bin/env bash
# Sweep ALL upstream Linux 6.6.50 files; restore anything missing in Samsung
# tree due to NTFS case-collision. Does not overwrite existing files.

set -e
SRC=/tmp/linux-6.6.50
DST=~/aether-rmx3171-6.6/kernel-6.6
restored=0
total=0

while IFS= read -r -d '' src; do
    total=$((total+1))
    rel="${src#$SRC/}"
    dst="$DST/$rel"
    if [ ! -e "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
        restored=$((restored+1))
    fi
done < <(find "$SRC" -type f \
            \( -name '*.h' -o -name '*.c' -o -name '*.S' -o -name 'Kconfig*' \
               -o -name 'Makefile*' -o -name '*.dtsi' -o -name '*.dts' \
               -o -name '*.json' -o -name '*.yaml' -o -name '*.txt' \
               -o -name '*.tbl' \) \
            -print0 2>/dev/null)

echo "[+] scanned $total upstream files, restored $restored"
