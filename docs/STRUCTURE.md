# Repo Structure — `aether-rmx3171-6.6/`

Single repo, dual artifact (kernel + Android device tree). Designed to be
git-cloneable + buildable on Ubuntu 22.04 + WSL.

> 2026-05-14 note: the production RMX3171 path is stock boot-header-v2 +
> physical dtbo. `BoardConfigA16Legacy.mk` is the default board overlay.
> `BoardConfigA16.mk` / physical `vendor_boot` / physical `init_boot` are
> PGPT-remap experiments only. Full ROM builds should add logical
> `vendor_dlkm` / `system_dlkm` inside stock `super.img`.

```
aether-rmx3171-6.6/
│
├── README.md                       Honest summary + which release to pick
├── CONTRIBUTING.md                 How to send patches
├── RELEASES.md                     Per-release notes (v1 → v4 history)
├── LICENSE                         GPL-2.0
├── .gitignore                      blocks: out/ kernel-6.6/ device-modules/ logs
├── .github/                        CI workflows + issue templates
│
├── aether-rmx3171/                 ★ AETHER overlay (the only thing we own)
│   ├── configs/                    kernel .config fragments
│   │   └── aether_rmx3171_overlay.config       77 CONFIG_ overrides
│   ├── dts/                        device-tree overrides
│   │   ├── mt6768-rmx3171.dts                  270 lines — board top-level
│   │   ├── cust_mt6768_rmx3171_pinctrl.dtsi    462 lines — 95 pin groups
│   │   └── rmx3171_bat_profile.dtsi            106 lines — 4×5 fuelgauge
│   ├── modules/                    module load manifests
│   │   ├── vendor_boot.modules.load            49 boot-critical .ko
│   │   └── vendor_dlkm.modules.load            208 late-init .ko
│   ├── ports/                      4.14→6.6 driver ports
│   │   ├── pinctrl/                ✅ DONE — pinctrl-mt6768 in vmlinux
│   │   │   ├── pinctrl-mt6768.c        88 lines (5 API fixes from 4.14)
│   │   │   └── pinctrl-mtk-mt6768.h    2750 lines pin tables
│   │   ├── configs/
│   │   │   └── aether_mtk_enable.config        117 MTK CONFIG_ enables
│   │   └── TODO/                   port-task scaffolds for community
│   │       ├── README.md           master index + 4.14→6.6 API cheatsheet
│   │       ├── clk-mt6768/         P3 — DTS fixed-clocks strategy
│   │       ├── panel-ilt9881h/     P1 — DRM panel port playbook
│   │       ├── sia81xx-audio/      P2 — ASoC codec rewrite
│   │       ├── gm30-battery/       P3 — simple-gauge fallback
│   │       ├── fm-mt6631/          P2 — OOT module port
│   │       ├── goodix-fingerprint/ P2 — char-dev + SPI port
│   │       └── connsys-mt6768-wifi/ ✅ DONE — see REFERENCE.txt
│   ├── abi/                        ⚠ EMPTY — KMI allowlist goes here
│   ├── firmware/                   ⚠ EMPTY — staged blob files (gitignored)
│   ├── docs/                       ⚠ EMPTY — was placeholder
│   └── build/                      kernel build entry points
│       ├── build_aether_6_6.sh         build kernel + AnyKernel zip
│       ├── stage_headers.sh            stage dt-bindings into kernel-6.6
│       ├── restore_lost_headers.sh     NTFS case-collision recovery
│       └── restore_all_lost.sh         sweep + restore from upstream Linux
│
├── device/realme/RMX3171/          ★ Android device tree (126 files)
│   ├── BoardConfig.mk              base board config
│   ├── BoardConfigA16.mk           A16 overlay (vendor_boot, init_boot,
│   │                                vendor_dlkm, AVB v2 chain)
│   ├── AndroidProducts.mk          product entries
│   ├── aether_RMX3171.mk           product definition
│   ├── device.mk                   inherit-product chain
│   ├── init/                       9 init scripts:
│   │   ├── fstab.mt6768                       A11/A12 fstab
│   │   ├── fstab.mt6768.a16                   A16 fstab (ICE v2, slot select)
│   │   ├── init.aether_root.rc                KSU + Magisk + NetHunter hooks
│   │   ├── init.mt6768.rc                     base init
│   │   ├── init.mt6768.usb.rc                 USB gadget config
│   │   ├── init.connectivity.rc               wlan/bt/fm bring-up
│   │   ├── init.modem.rc                      ECCCI stub
│   │   ├── init.sensor_1_0.rc                 sensor hub
│   │   └── ueventd.mtk.rc                     /dev permissions
│   ├── sepolicy/                   21 .te files for custom HAL allow
│   ├── configs/                    runtime configs
│   │   ├── audio/audio_policy_configuration.xml
│   │   ├── manifests/{manifest, compatibility_matrix}.xml
│   │   ├── media/                  codec capabilities
│   │   ├── permissions/            android.hardware.* features
│   │   ├── seccomp/                syscall filters
│   │   ├── sensors/                sensors HAL config
│   │   ├── thermal/                thermal-engine config
│   │   └── wifi/                   p2p_supplicant + hostapd
│   ├── overlay/                    framework resource overrides
│   ├── rro_overlays/               runtime resource overlays
│   ├── fingerprint/                Goodix BiometricsFingerprint @2.1 HAL
│   ├── audio/                      audio_policy_configuration.xml
│   ├── lights/                     lights HAL
│   ├── keylayout/ + idc/           hardware key maps + input device cfg
│   ├── libshims/                   ABI compat shims for stock blobs
│   ├── ImsInit/ + interfaces/      IMS service stubs
│   ├── proprietary-files.txt       3457 blob paths (stock vendor)
│   └── proprietary-files-system.txt blob paths for system partition
│
├── docs/                           ★ Public-facing documentation
│   ├── 01_hardware_truth.md        evidence-pointed hardware facts
│   ├── BUILD.md                    standard build path
│   ├── KLEAF_BUILD.md              Samsung Kleaf/Bazel path
│   ├── STRUCTURE.md                ← THIS FILE
│   ├── MISSING.md                  ★ what's MISSING, with evidence
│   ├── A16_BRINGUP.md              A16-specific boot bringup notes
│   ├── VENDOR_BLOBS.md             firmware/blob extraction guide
│   └── status/                     per-date status snapshots
│       └── 2026-05-12.md           latest
│
├── scripts/                        ★ Build + release automation
│   ├── sync_samsung_base.sh        re-stage gitignored base sources
│   ├── build/                      kernel/dtbo/super build helpers
│   │   ├── pack_dtbo.sh            ⚠ TODO — build dtbo.img
│   │   └── pack_super.sh           ⚠ TODO — build super.img
│   └── release/                    release pipeline
│       ├── build_release.sh        ⚠ TODO — full release pipeline
│       └── sign_vbmeta.sh          ⚠ TODO — AVB production sign
│
├── tools/                          generic tools (committed, small)
│
├── vendor/realme/RMX3171/          proprietary blob staging area
│   └── proprietary/                gitignored — populated by extract_blobs.sh
│
└── releases/                       gitignored — .zip artifacts
                                    (distributed via GitHub Releases page)
```

## Gitignored — but expected on disk for builds

These are present in WSL ext4 working tree but **never committed**:

| Path | Size | Source |
|---|---:|---|
| `kernel-6.6/` | 1.6 GB | Samsung A055F Linux 6.6.50 |
| `device-modules/` | 323 MB | Samsung `kernel_device_modules-6.6` (Bazel-built MTK BSP) |
| `vendor-modules/mediatek/kernel_modules/` | 284 MB | MTK GMS-allowed kernel modules: `mtkcam` (camera), `gpu/mali_avalon` (Mali r49p1), `connectivity` (bt/wlan/fm/gps), `met_drv_v3` (perf), `afs_common_utils`, `hbt_driver_cus` |
| `KernelSU/` | ~5 MB | KernelSU repo (built into kernel-6.6 via symlink) |
| `AnyKernel3/` | ~10 MB | osm0sis flasher repo (zip output goes here) |
| `out/` | ~3 GB | kernel build outputs |
| `releases/` | ~400 MB | flashable .zip artifacts |
| `.build-logs/` | varies | dated build logs (rotated) |

Re-stage gitignored sources with `scripts/sync_samsung_base.sh`.

## Top-level files

| File | Purpose |
|---|---|
| `README.md` | First contact — what is this, which release to flash |
| `CONTRIBUTING.md` | PR workflow + style |
| `RELEASES.md` | Per-release changelogs |
| `LICENSE` | GPL-2.0 |

## CI

`.github/workflows/` — kernel build + lint + DTC validation on PR.
`.github/ISSUE_TEMPLATE/` — boot_failure, hardware_broken, port_request.
