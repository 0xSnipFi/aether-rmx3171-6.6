# Flashing AETHER RMX3171

Experimental. The Linux 6.6 track is not hardware-proven on RMX3171 yet.
Keep a full stock firmware package ready before testing.

## Real RMX3171 Layout

Narzo 30A / RMX3171 stock hardware is:

- non-A/B
- boot header v2
- physical `boot`
- physical `dtbo`
- physical `super`
- no physical `vendor_boot`
- no physical `init_boot`
- no physical `vendor_dlkm` / `system_dlkm`

Do not try to flash `vendor_boot.img` or `init_boot.img` on stock RMX3171.
Those partitions do not exist unless you are doing a separate PGPT-remap
experiment.

## Before You Flash

1. Unlock the bootloader.
2. Install a known-good RMX3171 custom recovery.
3. Charge battery above 50%.
4. Back up stock `boot.img` and `dtbo.img`:

```bash
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/stock_boot.img'
adb shell su -c 'dd if=/dev/block/by-name/dtbo of=/sdcard/stock_dtbo.img'
adb pull /sdcard/stock_boot.img
adb pull /sdcard/stock_dtbo.img
```

Also keep the full stock `.ozip` / SP Flash Tool package so you can recover
from a bad boot image or broken DTBO.

## Flash Kernel Zip

Use recovery for the AnyKernel zip:

```bash
adb reboot recovery
adb sideload AETHER_RMX3171_6.6_MT6768-*.zip
```

If sideload is not available, copy the zip to `/sdcard` and install it from
TWRP / OrangeFox.

## Flash DTBO

Only flash the generated `dtbo.img` when testing the matching AETHER device
tree:

```bash
adb reboot bootloader
fastboot flash dtbo dtbo.img
fastboot reboot
```

Keep `stock_dtbo.img` ready:

```bash
fastboot flash dtbo stock_dtbo.img
```

## Full Android 16 ROM Build

For a full Android 16 ROM, use the stock-GPT path:

- `boot.img` remains boot-header-v2
- `dtbo.img` remains a physical partition
- `vendor_dlkm` and `system_dlkm` should be logical partitions inside custom
  `super.img`, not new physical GPT partitions
- modules may also be staged in `/vendor/lib/modules` during early bring-up

## Do Not Do This On Stock RMX3171

```bash
fastboot flash vendor_boot vendor_boot.img
fastboot flash init_boot init_boot.img
fastboot flash vendor_dlkm vendor_dlkm.img
fastboot flash system_dlkm system_dlkm.img
```

These partitions are not present in the stock partition table.

## First Boot Checks

After a successful boot, collect:

```bash
adb shell uname -a
adb shell cat /proc/cmdline
adb shell lsmod
adb shell dmesg > dmesg-aether.txt
adb logcat -b all > logcat-aether.txt
```

Expected kernel string:

```text
6.6.50-AETHER-X-RMX3171-A16+
```

## Emergency Restore

If recovery still boots:

```bash
adb reboot bootloader
fastboot flash boot stock_boot.img
fastboot flash dtbo stock_dtbo.img
fastboot reboot
```

If fastboot/recovery do not boot, use the full RMX3171 SP Flash Tool stock
package. Do not flash a remapped PGPT unless you intentionally built and tested
that exact scatter/preloader/LK set.

## Known 6.6 Track Risks

The source now packages the RMX3171 panel, touch, audio PA, gauge, fingerprint,
charging helper, FM, ECCCI cellular modules, Panfrost, KernelSU, and NetHunter
support paths. Hardware proof is still required for:

- display/backlight
- touch
- audio speaker route
- charging current and thermal safety
- fingerprint enrollment
- WiFi/BT/FM firmware bring-up
- SIM/calls/data/VoLTE
- Mali G52 Android GLES performance
- MTK ISP3 camera preview/photo

