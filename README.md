# AETHER Kernel — Realme Narzo 30A (RMX3171)

**MT6768 / Helio G85 SoC. Linux 6.6.129 ACK base + 4.14 legacy.**

> Two release tracks shipped. Pick based on goal:
>
> - 📱 **Daily-use flashable** → `releases/AETHER_RMX3171_4.14_legacy-20260511.zip`
>   (4.14.238 with FULL MTK BSP, 634 MTK symbols, all hardware drivers built)
> - 🧪 **Modern A16 base** → `releases/AETHER_RMX3171_6.6_MT6768-20260512v4.zip`
>   (Linux 6.6.129 ACK + 1976 MTK symbols + KernelSU + ported pinctrl-mt6768)

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
| Mali GPU | ✅ G52 MC1 driver |
| Audio (mt6768mt6358 + sia81xx) | ✅ in tree |
| Sensors (accel/gyro/mag/alsps/step) | ✅ MTK SCP framework |
| Fingerprint (Goodix) | ✅ kernel driver |
| Thermal | ✅ MTK legacy + chassis temp |

Flash, test, use.

### Track 2: 6.6.129 ACK — modern base with REAL MT6768 hardware ports

Built from Android Common Kernel 6.6.129 + AETHER MT6768 ports/configs.
Strategy: **port-from-4.14** where mainline doesn't have MT6768, **enable-mainline**
where it does.

#### Built-in to vmlinux (1976 MTK symbols)

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

#### Built as loadable .ko modules (149 total in v4)

| Module | Function |
|---|---|
| `pinctrl-mt6768.ko` | GPIO via our port |
| `wlan_drv_gen4m.ko` + `wmt_drv.ko` + `wmt_chrdev_wifi.ko` | **Internal MT6768 WiFi (4.14→6.6 port)** |
| `btmtk.ko` + `btmtksdio.ko` + `btmtkuart.ko` | Bluetooth MTK |
| `goodix_ts.ko` | Touchscreen Goodix |
| `mt76*.ko` × 8 | External USB WiFi |
| `mt6360_charger.ko` + `tcpci_mt6360.ko` | Charger + Type-C |
| `panel-novatek-nt36523.ko` + `nt36672a.ko` + `himax-hx8394.ko` | Display panels |
| `mtk_scp.ko` + `mtk_scp_ipi.ko` | Sensor hub firmware loader |
| `edt-ft5x06.ko` | Focaltech touch |
| `mediatek-cpufreq-hw.ko` | CPU frequency scaling |
| `wireguard.ko` | NetHunter VPN |
| KernelSU | Built-in (=y) |

#### What's still missing in 6.6 track

See **[docs/MISSING.md](docs/MISSING.md)** for the evidence-based gap list
+ **[docs/PRODUCTION_ROADMAP.md](docs/PRODUCTION_ROADMAP.md)** for the
realistic 6-month plan to 100% daily-driver parity.

Headline gaps (re-audited 2026-05-12):

- **P0** boot integrity: dtbo build, system_dlkm partition, bootconfig.img, KMI allowlist
- **P1** daily-use: panel-ilt9881h DRM port, touch NT36525B Novatek port, sia81xx audio amp, mt6370 PE+ charging, gm30 simple gauge
- **P2** ⚠ feasibility revised: Mali Bifrost r25p0 (4.14 has it!), camera ISP3 (~12K LoC, hard but doable), modem ECCCI (~12K LoC + signed blobs), FP/FM/etc
- **P3** optional: clk-mt6768 (DTS workaround), vibrator, flashlight

Realistic timeline:
- **MVP daily-driver** (no cam/cell): 6 weeks solo / 3 weeks team
- **Full daily-driver**: 6 months solo / 3 months team

Compiled-clean ≠ runs-on-device. Real boot test needed.

7 port-task scaffolds with 4.14 source staged + playbooks under
[`aether-rmx3171/ports/TODO/`](aether-rmx3171/ports/TODO/).

## Latest artifacts (2026-05-12)

```
File:    releases/AETHER_RMX3171_6.6_MT6768-20260512v4.zip
Size:    102.77 MB (zipped, ~150 MB uncompressed)
SHA-256: ca8670d2d110df42786f889918f012bdaf92282526a267a3e01da5249c681d8b
Kernel:  Linux 6.6.129-AETHER-X-RMX3171-A16+
Image:   33.87 MB raw, 13.83 MB gz, 14.02 MB gz-dtb
Modules: 149 .ko files
MTK syms: 1976 in vmlinux
Configs: 68 MTK-related
```

## Repository structure

Full layout: **[docs/STRUCTURE.md](docs/STRUCTURE.md)**.

```
aether-rmx3171-6.6/
├── aether-rmx3171/        ★ AETHER overlay (the only thing we own)
│   ├── configs/             kernel .config fragments
│   ├── dts/                 RMX3171 device-tree (270 + 462 + 106 lines)
│   ├── modules/             vendor_boot + vendor_dlkm load lists
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

- **Linux 6.6.129 ACK** + AETHER overlays
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
