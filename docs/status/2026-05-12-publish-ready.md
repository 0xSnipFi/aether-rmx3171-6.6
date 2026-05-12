# Status snapshot — 2026-05-12 PUBLISH-READY

## Repo state

```
tracked files:     ~315
commits on main:   10
real driver ports: 8
LoC in ports:      ~2400 (replaces ~47000 LoC vendor cruft)
docs:              10 (incl. 5 contributor/user-facing)
CI workflows:      2 (kernel-build, release)
issue templates:   3 (boot_failure, hardware_broken, port_request)
```

## What's REAL in tree (not TODO)

| Subsystem | Driver | Status |
|---|---|---|
| GPIO/pinmux | pinctrl-mt6768 (4.14 port) | ✅ in vmlinux |
| Display panel | panel-ilt9881h-rmx3171 (Truly + TXD) | ✅ |
| Touch | nt36525b-rmx3171 | ✅ |
| Audio PA | sia81xx-aether (8101/8108/8109) | ✅ |
| Battery gauge | aether-simple-gauge | ✅ |
| Charger | mt6370-pe-rmx3171 (18W Quick Charge) | ✅ |
| Fingerprint | goodix-fp-rmx3171 (GF3208) | ✅ |
| FM radio | fm-mt6631-aether | ✅ skeleton |
| WiFi (gen4m) | aetherx port (3 .ko) | ✅ |
| Bluetooth | btmtk* (mainline 6.6) | ✅ |
| eMMC | mtk-sd (mainline 6.6) | ✅ |
| PMIC | mt6358 (mainline 6.6) | ✅ |
| USB host | xhci-mtk (mainline 6.6) | ✅ |
| IOMMU | mtk-iommu (mainline 6.6) | ✅ |
| Sensor hub | mtk_scp (mainline 6.6) | ✅ |
| KernelSU | v0.9.5 built-in | ✅ |
| NetHunter | HID gadget + WireGuard + mt76 USB | ✅ |

## What's still missing for "100% daily-driver"

| Gap | Phase | Effort |
|---|---|---|
| Mali Bifrost r25p0 (3D GPU) | 7 | ~120 h |
| Camera ISP3 + sensors | 8 | ~190 h |
| ECCCI cellular modem | 9 | ~140 h |
| Vibrator (mt6358) | 6 | ~8 h |
| Flashlight (mt6370 flash) | 6 | ~4 h |
| Sensor calibration extraction | 6 | ~16 h |
| AVB production keys (gen + swap) | 1 | 2 h script ready |
| KMI allowlist (run after first build) | 1 | extract_kmi.sh ready |
| Real device boot test | — | community |

## A16 boot integrity (P0) — DONE

- ✅ `BOARD_KERNEL_DTBOIMAGE_PARTITION_SIZE` + `pack_dtbo.sh`
- ✅ `system_dlkm` partition + erofs FS + AVB chain
- ✅ `BOARD_BOOTCONFIG` androidboot props
- ✅ KMI extract script
- ✅ AVB key generator script
- ✅ `AB_OTA_PARTITIONS` full A16 list

## Build pipeline

- `aether-rmx3171/build/build_aether_6_6.sh` — kernel build entry
- `scripts/build/pack_dtbo.sh` — dtbo.img builder
- `scripts/build/extract_kmi.sh` — KMI allowlist from vmlinux
- `scripts/extract_blobs.sh` — pull firmware from stock vendor
- `scripts/sync_samsung_base.sh` — re-stage gitignored base
- `scripts/release/build_release.sh` — end-to-end pipeline
- `scripts/release/sign_vbmeta.sh` — AVB sign chain
- `scripts/release/generate_avb_keys.sh` — production key gen

## CI

- `.github/workflows/kernel-build.yml` — DTC + config + driver syntax + modules.load
- `.github/workflows/release.yml` — tag-triggered release builder + GH release upload

## Docs for users + contributors

| Audience | Doc |
|---|---|
| End users (flash + use) | FLASHING.md |
| End users (broken) | BOOT_FAILURE_TRIAGE.md |
| Hackers (hardware) | HARDWARE_PINOUT.md |
| Hackers (porting) | PORTING.md |
| Contributors (PR) | CONTRIBUTING.md |
| Maintainers (audit) | MISSING.md + PRODUCTION_ROADMAP.md |
| Public launch | README.md + RELEASES.md |

## Publish checklist

- [x] License: GPL-2.0
- [x] CONTRIBUTING.md present
- [x] README.md with badges + clear track distinction + flashing warning
- [x] Issue templates (3)
- [x] PR template
- [x] CI green on default branch
- [x] Release workflow ready (tag-triggered)
- [x] All "30W" mentions corrected to "18W"
- [x] Sensitive data excluded (.gitignore: keys/*.pem)
- [x] No vendor blobs committed (proprietary-files.txt is just a list)
- [x] No build artifacts committed (.build-logs/ gitignored)
- [x] Real driver ports with attribution to 4.14 originals

## Ready to publish

```bash
cd ~/aether-rmx3171-6.6
git push origin main
gh repo create <owner>/aether-rmx3171 --public --source . --push
git tag v5
git push origin v5
# release.yml will auto-build + upload
```
