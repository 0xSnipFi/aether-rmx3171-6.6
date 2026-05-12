# Vendor blob / firmware extraction guide

`device/realme/RMX3171/proprietary-files.txt` lists **3457 files**. Not all
are equal. This doc tells you which to extract first.

## Categories

### Boot-critical (won't boot without)

Pull these from stock `vendor.img` + `vendor_dlkm.img` + `vendor_boot.img`
before first flash:

| File | Path on stock | Why |
|---|---|---|
| `WIFI_RAM_CODE_MT6768.bin` | `/vendor/firmware/` | gen4m WiFi probe |
| `BT_RAM_CODE_MT6631.bin` | `/vendor/firmware/` | bluetooth chip |
| `GPS_FW_MT6631.bin` | `/vendor/firmware/` | GPS combo |
| `mt6358-codec.bin` | `/vendor/firmware/` | audio DSP coefficients |
| `nvram_config_*.bin` | `/vendor/nvdata/` | calibration backups (NV) |
| `WIFI_NVRAM_MT6768.bin` | `/vendor/firmware/` | per-device WiFi calib |

### Display panel-specific

| File | Why |
|---|---|
| `panel-ilt9881h-truly.cfg` | LCM init params (if extracted) |
| `disp_calibration_*.bin` | gamma / color tuning |

(Currently no panel driver = no display = these don't matter yet.)

### Audio (HAL-side)

| File | Purpose |
|---|---|
| `audio_param.xml` | mt6358 codec params per-device |
| `Dirac*.bin` + `libDiracAPI_SHARED.so` | speaker effects |
| `vendor/lib*/hw/audio.primary.mt6768.so` | audio HAL |
| `vendor/lib*/libaudiocompensationfilter*.so` | output EQ |

### Camera (NO camera kernel driver = these don't help)

3457 files include ~600 camera blobs. Skip for now.

### GPU userspace

| File | Why |
|---|---|
| `vendor/lib*/egl/libGLES_mali.so` | Mali userspace driver — **must match
  kernel Mali driver version** |
| `vendor/lib*/hw/gralloc.mt6768.so` | gralloc HAL (uses Mali allocator) |
| `vendor/lib*/hw/hwcomposer.mt6768.so` | display composer |

(No kernel Mali r34/r38 ported = userspace falls back to swiftshader.)

### Fingerprint

| File | Why |
|---|---|
| `vendor/lib*/hw/fingerprint.gf3208.so` | Goodix HAL |
| `vendor/etc/fingerprint_*.conf` | sensor config |
| `gxfp_config.bin` | tuning |

Need kernel `goodix_fp.ko` ported first.

### Cellular (skip — no modem driver)

`md1img.img`, `md1dsp.img`, `modem_*`, `*RIL*` — all skip.

## Extraction script — `scripts/extract_blobs.sh`

```bash
#!/usr/bin/env bash
# Mount stock vendor.img and pull listed files.
# Usage: extract_blobs.sh <path-to-stock-vendor.img>

set -e
VND=$1
[ -f "$VND" ] || { echo "Usage: $0 stock-vendor.img"; exit 1; }

MNT=$(mktemp -d)
sudo mount -o ro,loop "$VND" "$MNT"

OUT=~/aether-rmx3171-6.6/vendor/realme/RMX3171/proprietary
mkdir -p "$OUT"

# Boot-critical only
for f in \
    firmware/WIFI_RAM_CODE_MT6768.bin \
    firmware/BT_RAM_CODE_MT6631.bin \
    firmware/GPS_FW_MT6631.bin \
    firmware/mt6358-codec.bin \
    firmware/WIFI_NVRAM_MT6768.bin \
    nvdata/nvram_config_*.bin; do
    src="$MNT/$f"
    if [ -f "$src" ]; then
        dest="$OUT/firmware/$(basename $f)"
        mkdir -p "$(dirname $dest)"
        cp -v "$src" "$dest"
    else
        echo "MISSING in stock: $f"
    fi
done

sudo umount "$MNT"
rmdir "$MNT"
echo "[+] Boot-critical blobs in $OUT/"
```

(Not yet committed — TODO: add to `scripts/extract_blobs.sh`.)

## Legal note

Proprietary blobs are **NOT redistributed** in this repo. You must extract
them from your own stock RMX3171 device (or community dump). The
`vendor/realme/RMX3171/proprietary/` dir is `.gitignore`d.

LineageOS-style `proprietary-files.txt` lists the paths. Extraction is
on-you.

## Stock dump sources

If you don't have your own dump:

- **Realme A11 stock** — `RMX3171_11.A.13_2202_*.ozip` (decrypt with
  oppo-decrypt tool).
- **Community dump** — try
  [DumprX](https://github.com/DumprX-Project/DumprX) on the .ozip.

Verify SHA-256 of `vendor.img` matches the canonical dump before extracting.
