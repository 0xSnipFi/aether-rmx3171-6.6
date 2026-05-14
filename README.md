# AETHER Kernel — Realme Narzo 30A (RMX3171)

![License](https://img.shields.io/badge/license-GPL--2.0-blue)
![Kernel](https://img.shields.io/badge/linux-6.6.50-green)
![Device](https://img.shields.io/badge/device-Realme%20Narzo%2030A-orange)
![SoC](https://img.shields.io/badge/SoC-MT6768%20Helio%20G85-purple)
![Status](https://img.shields.io/badge/status-experimental-yellow)

**MT6768 / Helio G85 SoC · 6000 mAh · 18W Quick Charge · 720×1600 HD+**
**Linux 6.6.50 ACK base + 4.14 legacy track.**

## Current production target

The RMX3171/Narzo 30A stock partition table is non-A/B and boot-header-v2.
The real-device Android 16 path in this repo now defaults to:

- Linux 6.6 kernel packaged through the stock boot.img flow
- physical dtbo.img
- no physical vendor_boot or init_boot claim
- vendor_dlkm/system_dlkm as logical super partitions for full ROM builds
- modules staged in the AnyKernel zip for kernel-only recovery tests

Set `AETHER_BOOT_HEADER_VERSION=4` only for PGPT-remap/emulator experiments.
Do not advertise true certified GKI on stock RMX3171 hardware; this tree is a
custom 6.6 Android 16 bring-up that follows GKI/KMI practices where possible.

> Two release tracks. Pick based on goal:
>
> - 📱 **Daily-use flashable** → `AETHER_RMX3171_4.14_legacy-*.zip`
>   (4.14.238, full MTK BSP, 634 MTK symbols, proven hardware)
> - 🧪 **Modern A16 base** → `AETHER_RMX3171_6.6_MT6768-*.zip`
>   (6.6.50 ACK, KernelSU, 117 packaged modules, AETHER visible-hardware ports)
>
> **Before flashing read [`docs/FLASHING.md`](docs/FLASHING.md).**
> Track 2 is **untested on device**. If you boot it, post log via
> `boot_failure` issue template.

## Honest hardware coverage status

### Track 1: 4.14.238 — flashable, hardware proven

Built from Realme/OPPO `kernel_realme_moon` (4.14.238) which IS the MT6768 BSP.
All MTK drivers compile **in vmlinux** (634 MTK symbols). Validated build green.
Includes KernelSU v0.9.5 + NetHunter HID + WiFi-injection patches.

| Subsystem | State |
|---|---|
| Boot/storage (eMMC) | ✅ MTK MSDC built-in |
| Display LCM panels | ✅ all 6 Realme stock panels in tree |
| Touch | ✅ multi-vendor probe |
| Charging | ✅ MT6370 PMIC + 6000 mAh battery profile |
| WiFi/BT (Connsys MT6768) | ✅ full MTK BSP driver |
| FM (MT6631) | ✅ in tree |
| Camera ISP + sensors | ✅ 23 sensor candidates compiled |
| Mali GPU | ✅ G52 MC2-class Bifrost driver |
| Audio (mt6768mt6358 + sia81xx) | ✅ in tree |
| Sensors (accel/gyro/mag/alsps/step) | ✅ MTK SCP framework |
| Fingerprint (Goodix) | ✅ kernel driver |
| Thermal | ✅ MTK legacy + chassis temp |

Flash, test, use.

### Track 2: 6.6.50 ACK — Android 16 source-ready candidate

Built from Samsung A055F Linux 6.6.50 + AETHER MT6768/RMX3171 ports/configs.
Strategy: **port-from-4.14/4.19** where mainline doesn't have MT6768, **enable-mainline**
where it does.

#### Built-in to vmlinux / generated config proof

| Subsystem | Source | Symbols |
|---|---|---|
| **pinctrl-mt6768** | **AETHER port 4.14→6.6 (88-line C + 2750-line H, 5 API fixes)** | 4 init + handlers |
| MSDC eMMC | Mainline 6.6 mtk-sd | 113 |
| MTK DRM display framework | Mainline 6.6 drm/mediatek | 53 |
| MT6358 PMIC | Mainline 6.6 mfd/mt6397 + regulator | 33 |
| MT6370 charger + MFD | Mainline 6.6 mfd/mt6370 | 76 |
| MTK IOMMU | Mainline | 34 |
| MTK UART APDMA | Mainline | 23 |
| MTK HSDMA | Mainline | 23 |
| xhci-mtk USB host | Mainline | 21 |
| AuxADC | Mainline | 14 |
| MTK TPHY USB PHY | Mainline | 7 |
| MT6358 audio codec | Mainline ASoC | 4+ |
| MTK SCP firmware loader | Mainline (now =m) | scp_init |

#### Source-backed modules in the latest v7 release

| Module | Function |
|---|---|
| `panel-ilt9881h-rmx3171.ko` | RMX3171 ILT9881H panel slim port |
| `nt36525b-rmx3171.ko` | RMX3171 Novatek NT36525B touch slim port |
| `sia81xx-aether.ko` | RMX3171 SIA81xx speaker PA codec |
| `aether-simple-gauge.ko` | 6000 mAh battery profile gauge fallback |
| `goodix-fp-rmx3171.ko` | RMX3171 Goodix fingerprint slim port |
| `mt6370-pe-rmx3171.ko` | MT6370 PE+ charging helper |
| `fm-mt6631-aether.ko` | MT6631 FM radio slim port |
| `ccci_*`, `ccmni.ko`, `cpif.ko`, `rps_perf.ko` | MTK ECCCI modem kernel module set |
| `cfg80211.ko`, `mac80211.ko`, USB net modules | NetHunter/networking support |
| KernelSU | Built-in (`CONFIG_KSU=y`) |

#### What's still missing in 6.6 track

See **[docs/MISSING.md](docs/MISSING.md)** for the evidence-based gap list
+ **[docs/PRODUCTION_ROADMAP.md](docs/PRODUCTION_ROADMAP.md)** for the
realistic 6-month plan to 100% daily-driver parity.

Headline gaps (re-audited 2026-05-12):

- **P0** boot integrity: dtbo/system_dlkm/bootconfig now build; KMI allowlist, production AVB keys, and physical boot proof still missing
- **P1** daily-use: panel, touch, SIA81xx audio, PE+ charging, simple gauge, Goodix FP, and FM now build as AETHER modules but need RMX3171 hardware validation
- **P2** ⚠ hard ports: Mali Bifrost G52 full 3D and MTK ISP3 camera remain unsolved; cellular has kernel modules but still needs DTS/firmware/RIL/IMS/SIM test
- **P3** optional: clk-mt6768 (DTS workaround), vibrator, flashlight

Realistic timeline:
- **MVP daily-driver** (no cam/cell): now gated mainly by physical boot/test iteration
- **Full daily-driver**: 6 months solo / 3 months team

Compiled-clean ≠ runs-on-device. Real boot test needed.

Port-task scaffolds with 4.14/4.19 source staged + playbooks live under
[`aether-rmx3171/ports/TODO/`](aether-rmx3171/ports/TODO/). Current status:
[`docs/status/2026-05-13.md`](docs/status/2026-05-13.md).

## Latest artifacts (2026-05-13)

```
File:    releases/AETHER_RMX3171_6.6_MT6768-20260513v7-pinctrl-sourcefix.zip
SHA-256: b43a5022810cec86c14b6f3e9e0a2a7674c0e3af6012d4ed526ee692eefc5ef5
DTBO:    releases/dtbo.img
DTBO SHA-256: 7cf2a48edd7d8c01c9f5987434e19475f0798ba42308b9a424a5ef1274b41e5c
Kernel:  Linux 6.6.50 Samsung/AETHER base
Image:   27.08 MB raw, 12.00 MB gz, 12.20 MB gz-dtb
Modules: 117 packaged .ko files
Note:    untested on physical RMX3171
```

## Repository structure

Full layout: **[docs/STRUCTURE.md](docs/STRUCTURE.md)**.

```
aether-rmx3171-6.6/
├── aether-rmx3171/        ★ AETHER overlay (the only thing we own)
│   ├── configs/             kernel .config fragments
│   ├── dts/                 RMX3171 device-tree (270 + 462 + 106 lines)
│   ├── modules/             first-stage + vendor_dlkm + system_dlkm load lists
│   ├── ports/               ports/pinctrl (done), ports/TODO/ (7 scaffolds)
│   ├── abi/                 KMI allowlist (A16 GKI 2.0)
│   ├── firmware/            blob staging (gitignored)
│   └── build/               kernel build entry scripts
├── device/realme/RMX3171/  Android 16 device tree (126 files, full HAL/init/AVB/super)
├── docs/                    STRUCTURE, MISSING, A16_BRINGUP, VENDOR_BLOBS, status/
├── scripts/                 build + release automation
│   ├── build/pack_dtbo.sh   ★ NEW
│   └── release/build_release.sh  ★ NEW
├── vendor/realme/RMX3171/  proprietary blob staging (gitignored)
├── releases/                gitignored — distribute via GH Releases page
├── .github/                 CI + issue templates
└── README, CONTRIBUTING, RELEASES, LICENSE
```

Gitignored on-disk (re-staged via `scripts/sync_samsung_base.sh`):
`kernel-6.6/` (1.6 GB) · `device-modules/` (323 MB Samsung MTK BSP) ·
`vendor-modules/` (284 MB MTK kernel_modules: mtkcam/gpu/connectivity) ·
`KernelSU/` · `AnyKernel3/` · `out/`

## Quick start (build)

### Easiest path — community 6.6 build (rsuntkOrgs/a05m-kernel-6.6-master pattern)

```bash
# 1. Clone the community ACK 6.6 + MTK base
git clone https://github.com/rsuntkOrgs/a05m-kernel-6.6-master
cd a05m-kernel-6.6-master

# 2. Apply AETHER overlays (this repo)
cp <AETHER-repo>/aether-rmx3171/ports/pinctrl/pinctrl-mt6768.c \
   kernel-6.6/drivers/pinctrl/mediatek/
cp <AETHER-repo>/aether-rmx3171/ports/pinctrl/pinctrl-mtk-mt6768.h \
   kernel-6.6/drivers/pinctrl/mediatek/
cp <AETHER-repo>/aether-rmx3171/ports/configs/aether_mtk_enable.config .

# 3. Patch Kconfig + Makefile (see ports/README.md)

# 4. Apply config overlay
bash kernel-6.6/scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    aether_mtk_enable.config

# 5. Build (community script handles ACK + KernelSU + AnyKernel)
bash build_kernel.sh
```

### Full Samsung Kleaf path (advanced, for ~500 module BSP)

See `docs/KLEAF_BUILD.md`. Needs Samsung A055F source from
https://opensource.samsung.com + ~5 GB Android prebuilts.

## Features

- **Linux 6.6.50 ACK** + AETHER overlays
- **KernelSU** (kprobe root, built-in)
- **NetHunter-ready**: USB HID gadget, mac80211 monitor, WireGuard, 4× external USB WiFi adapter families
- **Magisk co-existence**: OVERLAY_FS, namespaces, init hooks
- **A16 features**: BPF_LSM, io_uring, KPROBES, DMABUF heaps, ICE, sha256 module sig, MODULE_COMPRESS_ZSTD
- **RMX3171 hardware data**: pinctrl 95 groups + battery 4×5 fuelgauge from stock A11 boot dtb
- **Pstore + ramoops** enabled (helps debug boot failures)

## License

GPL-2.0-only. See `LICENSE`.

- AETHER overlay code (this repo) — GPL-2.0
- KernelSU (fetched at build) — GPL-2.0
- AnyKernel3 (fetched at build) — see AK3 license
- Samsung A055F base / community a05m-kernel-6.6 — GPL-2.0 (not redistributed here)
- Realme 4.14 source (used as porting reference) — GPL-2.0

## Documentation

| Doc | For |
|---|---|
| [`docs/FLASHING.md`](docs/FLASHING.md) | Users — how to flash + recover |
| [`docs/BOOT_FAILURE_TRIAGE.md`](docs/BOOT_FAILURE_TRIAGE.md) | When it won't boot |
| [`docs/PARTITION_STRATEGY.md`](docs/PARTITION_STRATEGY.md) | Stock GPT + Android 16 logical dlkm strategy |
| [`docs/STRUCTURE.md`](docs/STRUCTURE.md) | Repo layout |
| [`docs/MISSING.md`](docs/MISSING.md) | P0–P3 gap audit |
| [`docs/PRODUCTION_ROADMAP.md`](docs/PRODUCTION_ROADMAP.md) | 6-month plan to full daily-driver |
| [`docs/A16_BRINGUP.md`](docs/A16_BRINGUP.md) | A16-specific boot reqs |
| [`docs/VENDOR_BLOBS.md`](docs/VENDOR_BLOBS.md) | Firmware extraction |
| [`docs/HARDWARE_PINOUT.md`](docs/HARDWARE_PINOUT.md) | GPIO / I²C / SPI map |
| [`docs/PORTING.md`](docs/PORTING.md) | Contribute a driver port |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | PR workflow |
| [`docs/status/`](docs/status/) | Per-date status snapshots |

## Real driver ports (8 in tree)

| File | LoC | Replaces |
|---|---:|---|
| `aether-rmx3171/ports/pinctrl/pinctrl-mt6768.c` | 91 + 2750 H | 4.14 pinctrl |
| `aether-rmx3171/ports/panel/panel-ilt9881h-rmx3171.c` | 363 | 4.14 LCM 607 |
| `aether-rmx3171/ports/input/nt36525b-rmx3171.c` | 356 | 4.14 NT36525B 3800 |
| `aether-rmx3171/ports/audio/sia81xx-aether.c` | 244 | 4.14 sia81xx 2512 |
| `aether-rmx3171/ports/power/aether-simple-gauge.c` | 391 | mtk_battery 5170 |
| `aether-rmx3171/ports/power/mt6370-pe-rmx3171.c` | 280 | mtk_pe 1500 |
| `aether-rmx3171/ports/misc/goodix-fp-rmx3171.c` | 367 | gf_spi+netlink 2500 |
| `aether-rmx3171/ports/connectivity/fm-mt6631-aether.c` | 320 | fmradio tree ~30000 |
| **Total** | **~2400 LoC** | **replaces ~47000 LoC vendor cruft** |

## Credits

Linux kernel community · MediaTek MT6768 BSP · Samsung Open Source · rsuntkOrgs
(a05m-kernel-6.6 community build) · KernelSU (tiann) · AnyKernel3 (osm0sis) ·
Kali NetHunter · Realme/OPPO 4.14 kernel sources (evidence reference)

## Disclaimer

**Experimental. Flash at own risk.** Backup stock recovery first. Track 1
(4.14) is the safer bet for daily use — it has proven working hardware
drivers compiled. Track 2 (6.6) is the modern future-facing build but
needs community device-test feedback before claiming daily-driver status.

No maintainer has flashed this on physical RMX3171 yet. If you do — please
submit boot logs via GitHub Issues using the `boot_failure` or
`hardware_broken` templates.
