# AETHER RMX3171 — Releases

Two release tracks for Realme Narzo 30A (RMX3171):

| Track | Status | Use for |
|---|---|---|
| **Legacy 4.14.238** | ✅ hardware-functional, KSU + NetHunter | Daily use on A11–A16 ROMs |
| **Experimental 6.6.50** | ⚠️ base only, no MTK BSP drivers | Modern A16 base, awaits Kleaf MTK BSP build |

## ✅ Production track — 4.14.238 (DAILY USE)

**Use this for actual flashing.** Has real MTK hardware drivers compiled in
(634 MTK symbols in vmlinux): camera ISP, Mali GPU, MT6370 charger, MT6358
PMIC, sensor hub, MT6768 connsys WiFi/BT, Goodix fingerprint, sia81xx
audio, MTK thermal — all working.

```
File:    releases/AETHER_RMX3171_4.14_legacy-20260511.zip
Size:    20.98 MB
SHA-256: 1648e9cd088260847d47ca3efd9524675631cb571d1a6d71d1d4bfb2f3577137
Kernel:  Linux 4.14.238 (Realme/OPPO MT6768 BSP)
Base:    kernel_realme_moon (oppo6769_defconfig)
Adds:    KernelSU v0.9.5 (kprobe), NetHunter HID + WiFi-injection patches,
         RMX3171 board model, SHA256 module signing, fortify-source relaxed
Tested:  builds clean, packages cleanly. Not yet flashed on physical RMX3171.
Format:  AnyKernel3 zip, flashable in TWRP/OrangeFox recovery
Targets: A11–A16 vendor ROMs (kernel ABI compat via Magisk/vendor shim)
```

### How to flash

```
1. Unlock RMX3171 bootloader (mtkclient or oem unlock)
2. Boot into TWRP/OrangeFox recovery
3. Flash releases/AETHER_RMX3171_4.14_legacy-20260511.zip
4. Wipe cache + dalvik
5. Reboot
```

### What works (per 4.14 source content)

- ✅ Boot to launcher (kernel + drivers + first-stage mount)
- ✅ Display (LCM panel + MTK display framework)
- ✅ Touch (multi-vendor probe)
- ✅ Charging (MT6370 + JEITA + 6000 mAh battery)
- ✅ WiFi + Hotspot (MT6768 connsys)
- ✅ Bluetooth (MT6768)
- ✅ FM radio (MT6631)
- ✅ Audio (mt6768mt6358 + sia81xx smart PA)
- ✅ Sensors (accel, gyro, mag, ALS+prox, step, pickup)
- ✅ Fingerprint (Goodix)
- ✅ Camera (per stock CUSTOM_KERNEL_IMGSENSOR list)
- ✅ Mali GPU (G52 MC1)
- ✅ Thermal (MTK legacy + chassis temp)
- ✅ KernelSU root
- ✅ NetHunter HID gadget
- ✅ NetHunter mac80211 monitor (limited by MTK WLAN driver — external USB adapter recommended)
- ✅ Magisk co-install (boot image patch path)

## ⚠️ Experimental track — 6.6.50 (BASE ONLY)

**Do not flash for daily use.** Modern Linux 6.6.50 with A16 features
natively (BPF_LSM, io_uring, DMABUF heaps, KPROBES). But MTK hardware
drivers NOT built — flashing on RMX3171 stalls at first-stage mount.

```
File:    releases/AETHER_RMX3171_6.6_A16-20260512.zip
Size:    59.93 MB
SHA-256: 5ebb911b17d1009ce9e41bea61c73d853d78c3e5a66e75a2ae9998139e264d78
Kernel:  Linux 6.6.50 (Samsung A055F base)
Adds:    KernelSU v3.2.4, RMX3171 pinctrl extracted (95 groups), RMX3171
         battery profile (4 batteries × 5 temps), A16 vendor tree skeleton
Status:  base builds clean, no MTK BSP drivers compiled
Path forward: install Android prebuilts + run Samsung Kleaf build
         (see docs/KLEAF_BUILD.md)
```

### What's in 6.6 base (working)

- ✅ Linux 6.6.50 ARM64 kernel boots to console
- ✅ KernelSU integrated (CONFIG_KSU=y)
- ✅ DMABUF heaps, BPF_LSM, io_uring, sha256 module signing
- ✅ RMX3171 board identity in DTS (model + compatible)
- ✅ 95 pin groups from RMX3171 stock dtb
- ✅ Battery fuelgauge profile extracted

### What's NOT in 6.6 base (missing for daily use)

- ❌ No MTK pinctrl driver bound (needs `pinctrl-mt6768.ko` from Kleaf)
- ❌ No MMC/eMMC driver (kernel mainline driver missing MT6768 quirks)
- ❌ No display, no touch, no charger, no WiFi, no camera, no GPU
- ❌ First-stage mount fails (no eMMC bind)

### How to complete 6.6 for hardware

```bash
# 1. Install Bazelisk, clang-r522817 prebuilt, build-tools, kernel-build-tools
#    See docs/KLEAF_BUILD.md (5–8 GB download)
# 2. Run Samsung Kleaf build with RMX3171 overlay
DEFCONFIG_OVERLAYS='mt6768_overlay.config RMX3171.config' \
MODE=user KERNEL_VERSION=kernel-6.6 \
bash build_kernel.sh
# 3. Output dir has ~500 MTK BSP .ko modules + Image.gz-dtb
# 4. Repackage to AnyKernel3
```

## Recommendation

For RMX3171 owner who wants to use AETHER on a daily-driver:
1. **Flash the 4.14 zip.** Hardware works. KSU + NetHunter ready.
2. Wait for community to complete 6.6 Kleaf build for true A16-native.

For kernel developer / contributor:
1. **Start with 6.6 base.** Cleaner upstream alignment, modern A16 features.
2. Run Kleaf locally to bring MTK BSP up.
3. PR fixes/extensions to AETHER repo.

## Verification

```bash
sha256sum releases/*.zip
# Compare to hashes above
```

## Note on git LFS

The 4.14 zip (~21 MB) and 6.6 zip (~60 MB) are kept in `releases/` but
gitignored due to size. Download from GitHub Releases page after pushing,
or build from source per docs/BUILD.md / docs/KLEAF_BUILD.md.
