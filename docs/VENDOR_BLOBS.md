# Vendor blob / firmware extraction guide

`device/realme/RMX3171/proprietary-files.txt` lists **3457 files**. Not all
are equal. This doc tells you which to extract first.

## Categories

### Boot-critical (won't boot without)

Pull these from stock `vendor.img` / `odm.img` / recovery ramdisk before first
flash. Stock RMX3171 does not have physical `vendor_boot` or `vendor_dlkm`
partitions.

| File | Path on stock | Why |
|---|---|---|
| `WIFI_RAM_CODE_soc1_0_1a_1.bin` | `/vendor/firmware/` | gen4m WiFi probe |
| `soc1_0_ram_wifi_1a_1_hdr.bin` | `/vendor/firmware/` | WiFi firmware header |
| `soc1_0_ram_bt_1a_1_hdr.bin` | `/vendor/firmware/` | Bluetooth firmware header |
| `soc1_0_ram_mcu_1a_1_hdr.bin` | `/vendor/firmware/` | connsys MCU firmware header |
| `soc1_0_patch_mcu_1a_1_hdr.bin` | `/vendor/firmware/` | connsys MCU patch header |
| `md1img.img` | `/vendor/firmware/`, stock dump root, or physical `md1img` image mirror | modem firmware image; required before ECCCI can boot modem |
| `md1dsp.img` | `/vendor/firmware/` or stock dump root mirror | modem DSP firmware; required for baseband bring-up. Current RMX3171 block-by-name dump has no physical `md1dsp` partition |
| `APDB_MT6768_S01__W2044*` | `/vendor/etc/apdb/` | modem database / APDB for RIL and modemdbfilter |
| `mtkfusionrild` + `libmtk-ril.so` | `/vendor/bin/hw/`, `/vendor/lib64/` | MTK RIL service and vendor radio userspace |
| OPLUS radio/IMS/appradio blobs | `/vendor/etc/vintf/`, `/odm/`, `/system_ext/` | VoLTE/IMS and Realme radio framework glue |
| `nvram_config_*.bin` | `/vendor/nvdata/` or `/nvdata/` | calibration backups (NV) |

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

### Camera

Camera blobs are useful now because the 6.6 tree packages experimental ISP3
kernel modules. They are still not enough by themselves; camera preview/photo
needs the ISP3 modules, DTS clocks/regulators, sensor tuple, and physical logs.

### GPU userspace

| File | Why |
|---|---|
| `vendor/lib*/egl/libGLES_mali.so` | Mali userspace driver — **must match
  kernel Mali driver version** |
| `vendor/lib*/hw/gralloc.mt6768.so` | gralloc HAL (uses Mali allocator) |
| `vendor/lib*/hw/hwcomposer.mt6768.so` | display composer |

Panfrost is the current open-source 6.6 path. Proprietary Mali userspace blobs
must match any future Bifrost DDK port; do not advertise Vulkan 1.3 on G52.

### Fingerprint

| File | Why |
|---|---|
| `vendor/lib*/hw/fingerprint.gf3208.so` | Goodix HAL |
| `vendor/etc/fingerprint_*.conf` | sensor config |
| `gxfp_config.bin` | tuning |

Need `goodix-fp-rmx3171.ko` loaded and matching TEE/HAL enrollment logs.

### Cellular

Do not skip cellular blobs for A16 bring-up. ECCCI/CCCI modules are packaged,
but cellular needs modem firmware and matching userspace:

- `md1img.img`
- `md1dsp.img`
- radio/RIL/IMS vendor blobs
- `/nvdata`, `/nvram`, `/nvcfg` calibration

## Extraction script — `scripts/extract_blobs.sh`

The committed script is the source of truth:

```bash
scripts/extract_blobs.sh <stock-vendor.img-or-mounted-dir> [stock-root-dir]
```

It stages files into both:

- `vendor/realme/RMX3171/proprietary/...` for the Android vendor makefiles
- `aether-rmx3171/firmware/...` for kernel bring-up and log triage

The script explicitly has a `modem firmware - do not skip` section for
`vendor/firmware/md1img.img` and `vendor/firmware/md1dsp.img`, then copies
RIL/IMS/APDB/OPLUS radio blobs. If a stock dump stores `md1img.img` or
`md1dsp.img` outside vendor, pass the dump root as the second argument so the
script can find the physical-partition image mirrors by basename.

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
