# Contributing to AETHER RMX3171 6.6

## Quick orientation

This repo is an Android 16 / Linux 6.6 kernel base for Realme Narzo 30A
(RMX3171, MT6768). The base comes from Samsung A055F (Galaxy A05M, same
SoC). Only RMX3171-specific overlay code lives in this repo. Samsung base
is not redistributed — `scripts/sync_samsung_base.sh` stages it from a
user-supplied Samsung kernel tarball.

## Which parts to PR

Original code (PR welcome, GPL-2.0):
- `aether-rmx3171/` — overlays, DTS, configs, scripts
- `device/realme/RMX3171/` — Android 16 device tree
- `vendor/realme/RMX3171/` — proprietary file lists (NOT blobs themselves)
- `docs/` — hardware truth, port plan
- `.github/` — CI, templates
- `scripts/` — sync + helper scripts
- `README.md`, `LICENSE`, `CONTRIBUTING.md`

Do NOT submit PRs that modify:
- `kernel-6.6/` — upstream Samsung A055F kernel (sync from upstream only)
- `device-modules/` — Samsung MTK BSP (sync from upstream only)
- `vendor-modules/` — Samsung Mali + vendor (sync from upstream only)
- `KernelSU/` — upstream KernelSU (auto-fetched)

If you find a bug in those, fix it as an overlay patch in `aether-rmx3171/`
or upstream the fix to the original project.

## Current high-priority gaps

1. **RMX3171 pinctrl dtsi**
   Stock 4.14 dtbdump (`mobile-karnal-build/realme_rmx3171_dump-*`) contains
   ~80 GPIO/pin function groups. Need to extract and rewrite as 6.6-style
   pinctrl bindings using `mt6768-pinfunc.h` macros. See
   `docs/01_hardware_truth.md` §1 + stock dtbdump file path.

2. **Battery profile arrays**
   Extract `battery0_profile_t0..t4` arrays verbatim from stock dtbdump
   into `aether-rmx3171/dts/rmx3171_bat_profile.dtsi`. 100 points × 5
   temperatures.

3. **MTK BSP Kleaf/Bazel build glue**
   Plain `make M=device-modules` fails on include-path issues. Either
   adopt Samsung's Kleaf build (with Android prebuilts) or write
   per-driver `Makefile.aether` glue. See `docs/KLEAF_BUILD.md`.

4. **Camera sensor identification**
   Stock `CUSTOM_KERNEL_IMGSENSOR` lists ~23 candidate sensors; RMX3171
   region uses 4. Identification needs first device boot log (dmesg | grep
   imgsensor).

5. **Real device boot test**
   No maintainer has flashed and booted on physical RMX3171 yet. Volunteer
   testers welcome. Required: UART or fastboot output of failed boot
   attempts so DTS overrides can be iterated.

6. **NetHunter port verification**
   Kernel configs are NetHunter-ready (HID gadget, mac80211 monitor, ext
   USB WiFi adapter drivers). Need verification once base boots.

## Coding standards

- DTS: use `mt6768-pinfunc.h` macros, not raw pinmux numbers. Every
  override must point to evidence in `docs/01_hardware_truth.md`.
- Config: add to `aether-rmx3171/configs/aether_rmx3171_overlay.config`,
  not directly to defconfig. One line, one comment explaining why.
- Vendor tree: keep `BoardConfig.mk` legacy A11-compatible, add A16
  deltas in `BoardConfigA16.mk` overlay.
- Init scripts: extend `init.aether_root.rc` for AETHER additions, don't
  modify upstream Samsung/MTK init.

## PR checklist

- [ ] Builds clean: `bash aether-rmx3171/build/build_aether_6_6.sh`
- [ ] DTC parses: `make mediatek/mt6768-rmx3171.dtb`
- [ ] Evidence cited for hardware changes (link to dtbdump line, stock prop, or vendor blob string)
- [ ] No vendor binary blobs committed (use `proprietary-files.txt` instead)
- [ ] No NTFS-case-collision-prone filenames added (test on case-sensitive fs)
- [ ] Tested on device if possible (boot log attached)

## Where to ask

- GitHub Discussions for design questions
- GitHub Issues for bugs (use templates in `.github/ISSUE_TEMPLATE/`)
- Telegram: TBD (community channel)

## Filing a hardware bug

Use the "Device boot failure" or "Hardware not working" issue template.
Include:
- Device variant (RMX3171, RMX3171L1, region)
- Stock ROM version flashed previously
- AETHER zip version + sha256
- dmesg output (UART or recovery shell)
- Steps to reproduce

## Community testing labs

Tag yourself in `docs/testers.md` PR if you have hardware available for
testing. Maintainers prioritize PRs that ship with reported boot results.
