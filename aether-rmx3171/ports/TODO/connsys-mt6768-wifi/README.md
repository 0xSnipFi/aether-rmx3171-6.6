# connsys-mt6768-wifi — DONE

WiFi for MT6768 internal connsys = MTK gen4m driver.

## Status: ported (3 .ko built)

Live at: `~/aetherx/AETHER-X_KARNAL-Narzo30A/source/mtk-gen4m-6.6-port/`

Produces:
- `wlan_drv_gen4m.ko` — wifi PCI/SDIO driver
- `wmt_drv.ko` — connsys arbiter
- `wmt_chrdev_wifi.ko` — char-dev `/dev/wmtWifi`

Already in v4 release zip. Pattern: out-of-tree module, builds against ACK
6.6 headers with `KDIR=` override.

If you need to rebuild:
```bash
cd ~/aetherx/AETHER-X_KARNAL-Narzo30A/source/mtk-gen4m-6.6-port
make KDIR=~/aether-rmx3171-6.6/kernel-6.6 ARCH=arm64 \
     CROSS_COMPILE=aarch64-linux-gnu- \
     CC=clang LD=ld.lld \
     -j$(nproc)
```

Modules land in `out/` → copy to `vendor_dlkm/lib/modules/`.

## Module load order

```
wmt_drv.ko          ← first (connsys arbiter)
wmt_chrdev_wifi.ko  ← user-space gate
wlan_drv_gen4m.ko   ← last (actual WiFi)
```

Already in `aether-rmx3171/modules/vendor_dlkm.modules.load`.

## Firmware

Needs `WIFI_RAM_CODE_MT6768.bin` in `/vendor/firmware/`. Pull from stock
RMX3171 vendor image. Without it = chip silent.

## Acceptance

- `lsmod` shows all 3.
- `dmesg | grep gen4m` shows successful firmware load.
- `wpa_supplicant` lists scanned networks.

## Status: P0 DONE.
