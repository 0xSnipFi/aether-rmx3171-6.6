# AETHER Kernel — Linux 6.6.50 for Realme Narzo 30A (RMX3171)

> Android 16 (RUI 7) compatible kernel base for Realme Narzo 30A.
> MT6768 / Helio G85 SoC. KernelSU + NetHunter + Magisk co-existence.
> **Status: experimental — base builds clean, MTK BSP integration in progress.**

---

## What this is

A clean Linux 6.6.50 kernel source tree configured specifically for the
Realme Narzo 30A (RMX3171). Built on top of Samsung's open-source A055F
(Galaxy A05M) BSP — which uses the **same MT6768 SoC** as RMX3171 —
plus RMX3171-specific overlays for hardware identity, device tree, and
A16 vendor tree.

## Target device

| Field | Value |
|---|---|
| Marketing name | Realme Narzo 30A |
| Model | RMX3171 |
| SoC | MediaTek Helio G85 (MT6769Z marketing / **MT6768 kernel platform**) |
| Board family | oppo6769 / RM6769 |
| Display | 720 × 1600 LCD |
| RAM | 4 GB / 3 GB |
| Storage | eMMC 5.1 (dynamic partitions, super.img) |
| Battery | 6000 mAh |
| Connsys | CONSYS_MT6768 (0x6768) WiFi + BT |
| FM | MT6631 |
| Fingerprint | Goodix (active) / Egis / FPC drivers shipped |

## Why Samsung A055F base?

Samsung's Galaxy A05M (SM-A055F) ships with **Linux 6.6.50** on the exact
same MT6768 SoC family. Their open-source kernel release includes a full
MTK BSP for MT6768 with modern Android 16 features (DMABUF heaps, io_uring,
BPF_LSM, native KPROBES). This makes it the **best modern base** for
porting to RMX3171 — same SoC, modern Android 16 / 6.6 substrate.

## Build status (honest)

| Stage | State |
|---|---|
| Linux 6.6.50 base | ✅ builds clean (clang-14 + LLD-14) |
| `Image.gz-dtb` | ✅ produced (12 MB) |
| `mt6768-rmx3171.dtb` | ✅ produced (160 KB) |
| KernelSU v3.2.4 | ✅ integrated (CONFIG_KSU=y) |
| 118 generic Linux modules | ✅ built (.ko) |
| MTK BSP modules (camera, GPU, charger, etc.) | ⚠️ in-progress — requires Samsung Kleaf/Bazel build (full Android prebuilts) |
| Pinctrl dtsi for RMX3171 | ⚠️ in-progress (Samsung A05M values applied as placeholder) |
| Real device boot test | ❌ not yet |

This base is **not yet a flashable Android 16 production kernel for daily
use on RMX3171**. It is the build infrastructure + scaffolding for one.
Full MTK BSP integration requires Samsung's Kleaf/Bazel build with
Android prebuilts (~10 GB download). See [BUILD.md](docs/BUILD.md).

## Repository layout

```
aether-rmx3171-6.6/
├── kernel-6.6/                Linux 6.6.50 base (stage from Samsung A055F)
├── device-modules/            Samsung MTK 6.6 BSP (stage from Samsung A055F)
├── vendor-modules/            Mali GPU + vendor (stage from Samsung A055F)
├── aether-rmx3171/            AETHER overlay — RMX3171 deltas (only this is original)
│   ├── configs/aether_rmx3171_overlay.config
│   ├── dts/mt6768-rmx3171.dts
│   ├── modules/vendor_boot.modules.load
│   ├── modules/vendor_dlkm.modules.load
│   └── build/
├── device/realme/RMX3171/     Android 16 device tree (BoardConfig, fstab, init)
├── vendor/realme/RMX3171/     Proprietary blob staging area (user provides)
├── KernelSU/                  KernelSU v3.2.4 (fetched at build time)
├── AnyKernel3/                AK3 packaging (fetched at build time)
├── docs/
│   └── 01_hardware_truth.md   Canonical RMX3171 hardware evidence
└── scripts/
    └── sync_samsung_base.sh   Stage Samsung A055F kernel into this tree
```

## Quick start (build)

### 1. Stage Samsung base (required — not in this repo)

```bash
# Download SM-A055F_15_Opensource.zip from https://opensource.samsung.com
unzip SM-A055F_15_Opensource.zip
export SAMSUNG_KERNEL_ROOT=/path/to/SM-A055F_15_Opensource/Kernel
bash scripts/sync_samsung_base.sh
```

### 2. Build (plain make path — base kernel only)

```bash
bash aether-rmx3171/build/build_aether_6_6.sh
```

Produces:
- `out/arch/arm64/boot/Image.gz-dtb`
- `out/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb`
- ~120 generic Linux `.ko` modules

### 3. Build full MTK BSP (Kleaf/Bazel path — required for working hardware)

```bash
# Needs Android prebuilts (~10 GB)
# See docs/KLEAF_BUILD.md
cd <samsung-kleaf-workspace>
DEFCONFIG_OVERLAYS='mt6768_overlay.config RMX3171.config' \
MODE=user KERNEL_VERSION=kernel-6.6 \
bash build_kernel.sh
```

### 4. Package for flash

```bash
bash scripts/package_anykernel.sh
# Output: out/AETHER_X_RMX3171_6.6-<date>.zip
```

## Features

- **Linux 6.6.50** with A16-ready features:
  - BPF_LSM, io_uring, KPROBES, DMABUF heaps, inline encryption
  - MODULE_SIG_HASH=sha256, MODULE_COMPRESS_ZSTD
- **KernelSU** v3.2.4 — kprobe-based root
- **NetHunter-friendly** kernel config:
  - USB HID gadget (configfs)
  - WireGuard
  - External USB WiFi adapters: RT3070/RT5572, AR9271, MT76, RTL8XXXU
  - mac80211 monitor/injection support
- **Magisk co-existence**:
  - OVERLAY_FS, namespaces, devtmpfs
  - init.aether_root.rc hooks for safe co-mounting
- **A16 vendor tree**:
  - boot v4 + vendor_boot + init_boot + vendor_dlkm split
  - fstab with FBE v2 + ICE + fsverity
  - VINTF + sepolicy carryover from RMX3171 A11 stock

## Hardware support status

| Subsystem | Status |
|---|---|
| Display (LCD 720×1600) | ⚠️ DTS values from stock; MTK display module needs Kleaf build |
| Touch | ⚠️ multi-vendor probe in DTS; controller drivers need Kleaf |
| Charging (MT6370) | ⚠️ stock values in DTS; charger module needs Kleaf |
| Battery (6000 mAh GM30) | ⚠️ profile arrays to be extracted from stock dtb |
| WiFi/BT (CONSYS_MT6768) | ⚠️ DTS ready; connsys driver needs Kleaf + firmware blobs |
| FM (MT6631) | ⚠️ same |
| Camera ISP + sensors | ⚠️ needs first-boot probe + Kleaf MTK imgsensor |
| GPU (Mali G52 MC1) | ⚠️ Mali avalon module needs Kleaf + Realme EGL blobs |
| Fingerprint (Goodix) | ⚠️ DTS node ready; HAL needs stock blob |
| Audio (mt6768mt6358 + sia81xx) | ⚠️ DTS routing ready; ASoC modules need Kleaf |
| Sensors (accel/gyro/mag/alsps) | ⚠️ MTK SCP sensor hub modules need Kleaf |
| Thermal (LVTS) | ⚠️ modern framework available; zone names match A16 HAL |

## Roadmap

- [x] Linux 6.6.50 base building clean
- [x] KernelSU integration
- [x] NetHunter kernel configs
- [x] Magisk co-existence init
- [x] RMX3171 hardware truth document
- [x] AnyKernel3 packaging
- [x] A16 vendor tree skeleton (BoardConfig, fstab, init)
- [ ] Full Samsung Kleaf/Bazel build adopted
- [ ] RMX3171 board target in Kleaf (replace S96818AA1)
- [ ] All MTK BSP modules building (.ko set)
- [ ] First boot on physical RMX3171
- [ ] Display + touch + charging
- [ ] WiFi + BT + audio + sensors + fingerprint
- [ ] GPU + camera + thermal
- [ ] Stable daily-driver
- [ ] CI build pipeline (GitHub Actions)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

Pull requests welcome for:
- Pinctrl dtsi extraction from RMX3171 stock dtb fragments
- Battery profile array extraction
- Camera sensor identification (need device boot log)
- MTK BSP build glue / Kleaf integration
- Vendor blob shim libraries
- A16 sepolicy patches

## License

GPL-2.0-only. See [LICENSE](LICENSE).

This repository contains:
- AETHER overlay code (original) — GPL-2.0
- KernelSU integration (fetched from upstream) — GPL-2.0
- AnyKernel3 packaging (fetched from upstream) — see AK3 license
- **Samsung A055F base and MediaTek BSP are NOT redistributed.** They must be
  downloaded separately from https://opensource.samsung.com and staged via
  `scripts/sync_samsung_base.sh`. Samsung's open-source release is also GPL-2.0.

## Credits

- Linux kernel community
- MediaTek for MT6768 BSP
- Samsung Open Source for A055F kernel release
- KernelSU project (tiann)
- AnyKernel3 (osm0sis)
- Kali NetHunter project
- Realme / OPPO 4.14 kernel sources (used as hardware evidence reference)

## Disclaimer

**Experimental software. Use at your own risk.** Flashing custom kernels can
brick your device. Make a stock recovery backup first. The maintainers are
not responsible for damage.

This kernel is **not yet** verified to boot on Realme Narzo 30A. Do not
flash on a daily-driver until the maintainer or community confirms a
successful boot test in a release announcement.
