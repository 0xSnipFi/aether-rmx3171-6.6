# Boot failure triage — RMX3171 6.6 kernel

When AETHER doesn't boot, work through this checklist top-to-bottom.

## Stage 1 — does fastboot see the device?

```bash
adb reboot bootloader
fastboot devices
```

| Result | Meaning | Fix |
|---|---|---|
| Device shown | Bootloader OK | Proceed to Stage 2 |
| Empty | Bootloader hung | Hold `Vol Down + Power 10 s` to force fastboot |
| `unauthorized` | RSA key not accepted | Accept USB debug on phone |

## Stage 2 — does kernel even start?

Watch for screen activity right after `fastboot reboot`:

| Symptom | Likely cause |
|---|---|
| Stuck on "POWERED BY REALME" splash | bootloader can't parse boot.img → wrong header version |
| Black screen, no vibration | kernel didn't decompress or DT incompatible |
| Black screen + vibration | kernel started, panic before display init |
| Bootloop (Realme splash -> off -> Realme splash) | early panic; check first-stage module list and fstab |

### Boot.img header check
```bash
unpack_bootimg --boot_img boot.img --out boot_extracted/
cat boot_extracted/header_*
```
Stock RMX3171 production builds should use `header_version=2`. Header v4 is
only for explicit PGPT-remap / emulator experiments.

## Stage 3 — capture kernel log via UART

RMX3171 has a hidden UART on USB-C pins (Realme dev mode). 921600 baud
8N1. Use ttyUSB adapter wired to:
- TX = USB-C CC1
- RX = USB-C CC2
- GND = USB-C GND

```bash
picocom -b 921600 /dev/ttyUSB0 > uart.log
```

What you should see during normal boot:
```
[    0.000000] Linux version 6.6.50-AETHER-X-RMX3171-A16+ ...
[    0.123456] OF: fdt: Machine model: Realme RMX3171
[    0.234567] mt6358-soc-pmic-wrapper: probe OK
[    0.345678] mtk-sd 11230000.mmc: ...
```

Look for the LAST line printed before hang. That's your error.

## Stage 4 — common errors & fixes

### `Unable to mount /vendor`
Cause: storage driver, DT, or wrong fstab entry.
Fix:
1. Check storage is built-in or available before first-stage mount.
2. Check `device/realme/RMX3171/init/fstab.mt6768.a16` has `/vendor` entry.
3. Rebuild kernel, re-flash.

### `Kernel panic - not syncing: Attempted to kill init!`
Cause: SELinux denying init transition or critical hal failed.
Fix:
1. Boot with `androidboot.selinux=permissive` temporarily in the stock-v2
   kernel cmdline.
2. Capture dmesg → look for `avc: denied` entries.
3. Add corresponding `allow` rule to `device/.../sepolicy/private/`.

### `panel-ilt9881h-rmx3171: vsp regulator missing`
Cause: DTS regulator phandle wrong.
Fix: check `aether-rmx3171/dts/mt6768-rmx3171.dts` panel node references
correct `dsv_pos` / `dsv_neg` regulators.

### `mtk-pmic-wrap: PMIC busy timeout`
Cause: MT6358 PMIC clock not enabled by bootloader.
Fix: confirm bootloader is Realme stock (NOT Samsung). Bootloader must
init PMIC before kernel starts.

### `gen4m: firmware not found`
Cause: missing `WIFI_RAM_CODE_soc1_0_1a_1.bin` or matching connsys firmware.
Fix: extract from stock vendor.img per `docs/VENDOR_BLOBS.md`.
Place in `/vendor/firmware/` via vendor partition flash.

### `aether-simple-gauge: battery-manager phandle missing`
Cause: DTS battery_manager label not defined in inherited Samsung dtsi.
Fix: ensure `cust_mt6768_msdc.dtsi` and battery dtsi are included before
the gauge node references it.

### Kernel panic, register dump only
Likely a NULL pointer deref. Need stack trace.
1. Enable `CONFIG_KASAN=y` in overlay.config.
2. Rebuild + reflash.
3. UART log will show the offending function.

## Stage 5 — rescue via download mode

If everything fails:

1. Plug phone OFF.
2. Hold `Vol Up + Vol Down`, plug USB.
3. Phone enters MTK BROM/Preloader mode.
4. SP Flash Tool flashes back stock.
5. Try again with different DTS / config tweak.

## Stage 6 — file a GitHub issue

After exhausting above, open `boot_failure` issue with:
- AETHER zip filename
- UART log (or recovery dmesg if no UART)
- Stage at which boot failed
- DTS / config changes from defaults

Maintainers will help if log is detailed.

## Quick-reference: bisecting panic location

Add `earlycon` to `BOARD_BOOTCONFIG` for very-early log:
```
BOARD_BOOTCONFIG += earlycon=uart8250,mmio32,0x11002000,921600n8
```

Now you'll see logs from the very first kernel instruction.

## Recovery shell access

If kernel boots but Android doesn't:
```bash
adb reboot recovery
adb shell
> dmesg | tail -200
> logcat -b all -d > /sdcard/logcat.txt
```

Even partial boot to recovery is a good debugging signal.
