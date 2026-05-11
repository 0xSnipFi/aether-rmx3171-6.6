#!/usr/bin/env bash
# Stage MT6768 dt-bindings headers from Samsung device-modules into kernel-6.6.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DT="$ROOT/device-modules/include/dt-bindings"
DST_DT="$ROOT/kernel-6.6/include/dt-bindings"

if [ ! -d "$SRC_DT" ]; then
    echo "[!] missing $SRC_DT"
    exit 1
fi

count=0
while IFS= read -r -d '' src; do
    rel="${src#$SRC_DT/}"
    dst="$DST_DT/$rel"
    if [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
        count=$((count+1))
    fi
done < <(find "$SRC_DT" -type f -name '*.h' -print0)

echo "[+] staged $count MTK dt-bindings headers"
