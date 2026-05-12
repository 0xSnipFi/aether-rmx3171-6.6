# Firmware blob staging

This dir is `.gitignore`d. Populated by `scripts/extract_blobs.sh` from stock
RMX3171 vendor.img.

## Required for boot

| File | Source path (stock) | Size approx |
|---|---|---:|
| `WIFI_RAM_CODE_MT6768.bin` | `/vendor/firmware/` | ~1 MB |
| `WIFI_NVRAM_MT6768.bin` | `/vendor/firmware/` | ~32 KB |
| `BT_RAM_CODE_MT6631.bin` | `/vendor/firmware/` | ~500 KB |
| `GPS_FW_MT6631.bin` | `/vendor/firmware/` | ~200 KB |
| `mt6358-codec.bin` | `/vendor/firmware/` | ~64 KB |

## How to populate

1. Get your RMX3171 stock vendor.img.
2. `bash scripts/extract_blobs.sh /path/to/stock-vendor.img`.
3. Files land in this dir.
4. AnyKernel3 picks them up at packaging time → `/vendor/firmware/`.

## Legal

Proprietary — never committed. See `docs/VENDOR_BLOBS.md`.
