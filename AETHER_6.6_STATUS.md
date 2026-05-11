# AETHER RMX3171 6.6 — current build state

This file complements the vendor tree README. It describes the **kernel-6.6
port progress** for Realme Narzo 30A / RMX3171.

## ===========================================================
## STATUS UPDATE (2026-05-11): KERNEL BUILD GREEN. ARTIFACTS REAL.
## ===========================================================

| Artifact | Size | SHA-256 (first 16) | Path |
|---|---|---|---|
| `Image` (raw ARM64) | 26.99 MB | — | `out/arch/arm64/boot/Image` |
| `Image.gz` | 11.97 MB | — | `out/arch/arm64/boot/Image.gz` |
| `Image.gz-dtb` (concat) | 12.13 MB | `e223023bb8d51c65` | `out/arch/arm64/boot/Image.gz-dtb` |
| `mt6768-rmx3171.dtb` | 160 KB | `7a00ad048b54552c` | `out/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb` |
| `.ko` modules | 118 | — | `out/**/*.ko` |
| AnyKernel3 zip | **60.24 MB** | `bc3287f6c7563149` | `AnyKernel3/AETHER_X_RMX3171_6.6_A16-20260511.zip` |

Build chain:
- Linux 6.6.50 base (Samsung A055F kernel-6.6)
- Toolchain: clang-14 + LLD 14 + aarch64-linux-gnu-gcc 11.4 + pahole 1.25
- Defconfig: Samsung a05m_defconfig + AETHER overlay (KernelSU, NetHunter, A16)
- DTS: `mt6768-rmx3171.dts` (240 lines, evidence-pointed overrides on Samsung mt6768.dts)
- KernelSU integrated: `drivers/kernelsu` symlink, `CONFIG_KSU=y`
- 118 vendor + crypto + net modules built

Build commands that produced this:

```bash
cd ~/aether-rmx3171-6.6/kernel-6.6
make ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- O=../out \
    aether_rmx3171_base_defconfig
bash scripts/kconfig/merge_config.sh -m -O ../out ../out/.config \
    arch/arm64/configs/aether_rmx3171_overlay.config
make ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- O=../out olddefconfig
make ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- O=../out -j16 \
    Image Image.gz modules mediatek/mt6768-rmx3171.dtb
cat ../out/arch/arm64/boot/Image.gz \
    ../out/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb \
    > ../out/arch/arm64/boot/Image.gz-dtb
```

## ===========================================================
## Original status section (pre-build) below
## ===========================================================


## Workspace

Located on WSL ext4 (`~/aether-rmx3171-6.6/`) to avoid NTFS case-collisions
that broke the 4.14 fork.

```
aether-rmx3171-6.6/
├── kernel-6.6/                 Samsung A055F Linux 6.6.50 kernel (1.5 GB)
├── device-modules/             Samsung kernel_device_modules-6.6 MTK BSP (284 MB)
├── vendor-modules/             Samsung vendor/mediatek/kernel_modules (284 MB)
├── aether-rmx3171/             AETHER overlay — RMX3171-specific deltas
│   ├── configs/aether_rmx3171_overlay.config
│   ├── dts/mt6768-rmx3171.dts
│   ├── modules/vendor_boot.modules.load
│   ├── modules/vendor_dlkm.modules.load
│   └── build/
│       ├── build_aether_6_6.sh
│       └── stage_headers.sh
├── device/realme/RMX3171/      Android 16 device tree
│   ├── BoardConfig.mk
│   ├── BoardConfigA16.mk       A16 overlay (vendor_boot, init_boot, vendor_dlkm)
│   ├── init/fstab.mt6768.a16   A16 fstab (ICE v2, vendor_dlkm, slotselect)
│   └── init/init.aether_root.rc KSU + Magisk coexistence
└── docs/01_hardware_truth.md   canonical RMX3171 hardware evidence
```

## Sanity build state — PASS

| Gate | State |
|---|---|
| ext4 workspace, 921 GB free | done |
| Samsung 6.6 kernel-6.6 copied | done (1.5 GB) |
| Samsung MTK 6.6 BSP copied | done (284 MB) |
| Samsung Mali GPU module copied | done (284 MB) |
| RMX3171 hw truth extracted from stock dtbdump | done (`docs/01_hardware_truth.md`) |
| AETHER overlay config written (logic-based, 110 lines) | done |
| AETHER DTS written (logic-based, 240 lines) | done |
| KernelSU integrated (drivers/kernelsu symlink + Makefile + Kconfig) | done (`CONFIG_KSU=y`) |
| Module load manifests written | done (vendor_boot + vendor_dlkm) |
| A16 BoardConfig overlay written | done (boot v4, init_boot, vendor_dlkm) |
| A16 fstab written | done (ICE v2, fileencryption v2, vendor_dlkm) |
| Init scripts for KSU+Magisk+NetHunter | done |
| defconfig merge: a05m_defconfig + AETHER overlay | **PASS** |
| `make olddefconfig` clean | **PASS** |
| DTC parse `mt6768-rmx3171.dtb` | **PASS** (160 KB output) |
| dtbo extract from stock | dtb included in `dump-RMX3171_11.A.13_0130`/dtbo |

## Verified config flips from Samsung a05m baseline

| Key | Samsung default | AETHER value | Why |
|---|---|---|---|
| MODULE_SIG_HASH | sha1 | sha256 | A16 stronger sig chain |
| MODULE_COMPRESS_ZSTD | n | y | shrink vendor_dlkm image |
| KSU | absent | y | root |
| OVERLAY_FS | y | y (preserved) | Magisk |
| ZRAM_DEF_COMP | lzo-rle | lz4 | faster swap on G85 |
| WIREGUARD | absent | y | NetHunter VPN |
| NFC | m | off | RMX3171 has no NFC |
| SCSI_UFSHCD | y | off | RMX3171 eMMC only |
| USB_CONFIGFS_F_HID | unset | y | NetHunter HID gadget |
| MT76_USB, RT2800USB, ATH9K_HTC | unset | m | NetHunter ext WiFi |
| TRANSPARENT_HUGEPAGE_ALWAYS | n | y | perf |

## Build commands (when clang-18 available)

```bash
cd ~/aether-rmx3171-6.6
bash aether-rmx3171/build/stage_headers.sh
bash aether-rmx3171/build/build_aether_6_6.sh
```

Toolchain hints:

```bash
# Install Android prebuilt clang-r510928 (matches Samsung's CC version)
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 ~/android-clang
export CC=$HOME/android-clang/clang-r510928/bin/clang
export PATH=$HOME/android-clang/clang-r510928/bin:$PATH
```

## Not yet done

| Item | Why blocked | Unblock path |
|---|---|---|
| Full kernel compile (Image.gz) | WSL clang-14 too old | install clang-18 prebuilt |
| MTK device modules build | Kbuild glue needed | wire kernel_device_modules-6.6 M= path |
| RMX3171 pinctrl dtsi | Stock dtbdump pin functions still to parse | extract from `dtbdump_fragment@0_1.dts` |
| Battery profile arrays | 100×5 numbers in stock dtb | extract verbatim into dtsi include |
| Camera sensor active tuple | needs device boot log | first device run |
| Mali DDK ↔ user blob match | needs blob inspection | check `vendor/lib*/egl/libGLES_mali.so` symbol versions |
| Touch chip identification | one of chipone/focaltech/novatek/omnivision/gcore | first boot probe |
| Fingerprint HAL ident | one of Goodix/Egis/FPC | check `vendor/lib*/hw/fingerprint.*.so` |
| Real boot test | no device in loop | flash + UART log |

## What runs vs what does not (honest)

Runs today:
- Sources fully staged and clean
- defconfig generation passes
- DTC parses the RMX3171 board to a real DTB
- Vendor tree A16 scaffold present
- Module load lists drafted

Does NOT run today:
- Image.gz compile (needs clang-18)
- Boot on device (needs P3-P8 of port plan)
- Camera/GPU stability (needs device + tuning)
- KernelSU functional test (needs boot)
- NetHunter monitor mode (needs boot + external USB adapter)

## Next actions (no device needed)

1. Install clang-18 prebuilt; rerun `build_aether_6_6.sh`.
2. Write `cust_mt6768_rmx3171_pinctrl.dtsi` from stock dtbdump fragment files.
3. Extract battery t0..t4 profile arrays verbatim into `rmx3171_bat_profile.dtsi`.
4. Re-include touch/charger/camera dtsi once pinctrl exists.
5. Stub MTK module Kbuild glue so out-of-tree modules build with plain make.

## Next actions (device-needed)

6. Flash boot.img + vendor_boot to test device (use fastboot, unlocked).
7. Capture dmesg via UART or recovery shell.
8. Iterate DTS overrides against probe failures.
9. Bring up display/touch/USB → WiFi/BT/audio → camera/GPU → polish.

See `mobile-karnal-build/AETHER_RMX3171_A16_6_6_TECHNICAL_BREAKDOWN_v2.md` for full plan.
