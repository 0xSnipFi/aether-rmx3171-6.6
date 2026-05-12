# Flashing AETHER RMX3171 — user guide

⚠ **EXPERIMENTAL. Flash at your own risk.** Track 2 (6.6) has NOT been
boot-tested on physical device yet. Track 1 (4.14) is the safer daily-use
option.

## What you need

| Item | Notes |
|---|---|
| Realme Narzo 30A (RMX3171) | unlocked bootloader required |
| USB-C cable + Windows / Linux PC | with `fastboot` + `adb` installed |
| Custom recovery (TWRP / OrangeFox) for RMX3171 | flash first |
| Stock RMX3171 firmware (.ozip) | for emergency restore |
| ~1 GB free on /sdcard | for AnyKernel zip |

## Before you flash

1. **Backup `/data` + `/system` + `/vendor`** via TWRP. You will brick it
   at some point during testing.
2. **Save stock `boot.img` + `vendor_boot.img` + `dtbo.img`**:
   ```bash
   adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/stock_boot.img'
   adb shell su -c 'dd if=/dev/block/by-name/vendor_boot of=/sdcard/stock_vendor_boot.img'
   adb shell su -c 'dd if=/dev/block/by-name/dtbo of=/sdcard/stock_dtbo.img'
   adb pull /sdcard/stock_boot.img
   adb pull /sdcard/stock_vendor_boot.img
   adb pull /sdcard/stock_dtbo.img
   ```
3. **Charge to >50%** — kernel testing can cause unexpected reboots.

## Pick a track

| Track | Goal | File |
|---|---|---|
| **Track 1: 4.14 legacy** (recommended for daily use) | flashable, full MTK BSP, proven hardware | `AETHER_RMX3171_4.14_legacy-*.zip` |
| **Track 2: 6.6 modern** (experimental) | ACK 6.6 + AETHER overlays, GKI 2.0, A16 base | `AETHER_RMX3171_6.6_MT6768-*.zip` |

Download latest from
[Releases](https://github.com/<owner>/aether-rmx3171-6.6/releases).

## Flash via custom recovery (recommended)

1. Reboot to recovery: hold `Power + Volume Down`.
2. **Wipe Dalvik / cache** (NOT data unless clean install).
3. **Install zip** → pick `AETHER_RMX3171_*.zip` from `/sdcard`.
4. AnyKernel3 patches `boot.img` and reboots automatically.

For Track 2 (6.6) you also need to flash `dtbo.img` separately:
```
fastboot flash dtbo dtbo.img
```

## Flash via fastboot (advanced)

Boot to bootloader:
```
adb reboot bootloader
```

Track 2 (A/B partition):
```bash
# A16 layout — flash all six images
fastboot flash boot           boot.img
fastboot flash init_boot      init_boot.img
fastboot flash vendor_boot    vendor_boot.img
fastboot flash dtbo           dtbo.img
fastboot flash vendor_dlkm    vendor_dlkm.img
fastboot flash system_dlkm    system_dlkm.img

# Sign chain
fastboot flash vbmeta         vbmeta.img
fastboot flash vbmeta_system  vbmeta_system.img
fastboot flash vbmeta_vendor  vbmeta_vendor.img

fastboot reboot
```

Track 1 (legacy v2 boot):
```bash
fastboot flash boot boot.img
fastboot reboot
```

## Verify after first boot

```bash
adb shell uname -r
# Expect: 6.6.50-AETHER-X-RMX3171-A16+

adb shell dmesg | grep -i 'aether\|panel-ilt\|nt36525\|gen4m\|btmtk' | head -20
# Expect to see probe success lines for ported drivers.

adb shell lsmod | wc -l
# Expect ~149 modules.

# KernelSU manager APK should detect kernel root.
```

## Emergency restore — if you brick it

### Soft brick (boot loop)

1. Boot to recovery.
2. Flash stock `boot.img` + `vendor_boot.img` + `dtbo.img` you backed up.
3. Wipe Dalvik + cache.
4. Reboot.

### Hard brick (no boot to recovery)

Use MTK SP Flash Tool:
1. Download Realme RMX3171 stock firmware `.ozip`.
2. Decrypt with `oppo-decrypt` tool.
3. Open SP Flash Tool, load `MT6768_Android_scatter.txt`.
4. Tick all partitions → `Download`.
5. Plug phone (powered off) → wait for SP Flash Tool to detect Preloader mode.
6. After ~5 min flash finishes, phone reboots to stock.

Tutorial: search "RMX3171 SP Flash Tool stock restore" on XDA.

## Known issues (Track 2 / 6.6)

| Symptom | Cause | Workaround |
|---|---|---|
| Black screen after boot | panel-ilt9881h not yet device-tested | wait for community fix |
| Touch unresponsive | NT36525B FW load may need stock firmware blob | extract from stock vendor.img |
| Audio quiet | sia81xx PA driver not yet device-tested | use headphones |
| Battery % jumpy | gauge uses voltage curve (±3%) | acceptable; recalibrate stock |
| WiFi/BT silent | needs `WIFI_RAM_CODE_MT6768.bin` from stock | extract per `docs/VENDOR_BLOBS.md` |
| Camera apps crash | no camera driver in 6.6 yet | use 4.14 track |
| No cellular | no modem driver | use 4.14 track |
| No 3D in games | Mali driver pending | use software fallback |

## Report problems

Open a GitHub Issue using the `boot_failure` or `hardware_broken` template.
Include:
- `dmesg` output (`adb shell dmesg > dmesg.txt`)
- Logcat (`adb logcat > logcat.txt`)
- AETHER version (filename of zip flashed)
- Symptoms in plain English

## Uninstall AETHER

Flash back stock from your backup, then:
```bash
adb shell rm -rf /data/adb/ksu  # remove KernelSU
adb reboot
```

You may want to factory-reset stock data to clear any KernelSU residue.
