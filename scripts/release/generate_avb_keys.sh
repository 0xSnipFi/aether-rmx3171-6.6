#!/usr/bin/env bash
# AETHER RMX3171 — generate production AVB signing keys.
#
# Usage: scripts/release/generate_avb_keys.sh [output-dir]
#
# Produces:
#   <out>/aether_avb_key.pem       2048-bit RSA private key (KEEP SECRET)
#   <out>/aether_avb_pubkey.bin    AVB-format public key (commits to repo)
#
# Replaces test keys in BoardConfigA16.mk. After generating, update:
#   BOARD_AVB_VBMETA_*_KEY_PATH := <out>/aether_avb_key.pem

set -euo pipefail

OUT="${1:-aether-rmx3171/keys}"
mkdir -p "$OUT"

if [ -f "$OUT/aether_avb_key.pem" ]; then
    echo "ERROR: $OUT/aether_avb_key.pem already exists — won't overwrite"
    exit 1
fi

if ! command -v openssl >/dev/null; then
    echo "[!] openssl missing — install with: apt install openssl"
    exit 1
fi

if ! command -v avbtool >/dev/null; then
    echo "[!] avbtool missing — install with: apt install android-tools-fsutils"
    exit 1
fi

echo "[1/3] generate 2048-bit RSA private key"
openssl genrsa -out "$OUT/aether_avb_key.pem" 2048
chmod 600 "$OUT/aether_avb_key.pem"

echo "[2/3] extract AVB-format public key"
avbtool extract_public_key \
    --key "$OUT/aether_avb_key.pem" \
    --output "$OUT/aether_avb_pubkey.bin"

echo "[3/3] fingerprint"
openssl rsa -in "$OUT/aether_avb_key.pem" -pubout -outform DER 2>/dev/null \
    | sha256sum

cat <<EOF

[+] Keys generated.
    Private: $OUT/aether_avb_key.pem        (KEEP SECRET — DO NOT commit)
    Public:  $OUT/aether_avb_pubkey.bin     (commit to repo)

Update device/realme/RMX3171/BoardConfigA16.mk:

  BOARD_AVB_VBMETA_VENDOR_BOOT_KEY_PATH := \$(LOCAL_PATH)/../../../keys/aether_avb_key.pem
  BOARD_AVB_VBMETA_VENDOR_DLKM_KEY_PATH := \$(LOCAL_PATH)/../../../keys/aether_avb_key.pem
  BOARD_AVB_VBMETA_SYSTEM_DLKM_KEY_PATH := \$(LOCAL_PATH)/../../../keys/aether_avb_key.pem
  BOARD_AVB_INIT_BOOT_KEY_PATH          := \$(LOCAL_PATH)/../../../keys/aether_avb_key.pem

Then ensure $OUT/aether_avb_key.pem is in .gitignore.
EOF
