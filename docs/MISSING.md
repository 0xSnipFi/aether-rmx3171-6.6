# What's MISSING for full RMX3171 A16 daily-driver — evidence-based

> **2026-05-12 UPDATE — re-audit corrections:** Several "infeasible"
> claims below have been **REVISED — see `PRODUCTION_ROADMAP.md`**. Quick
> corrections:
> - **Mali GPU**: 4.14 has Bifrost r25p0 (right family) → port FEASIBLE
> - **Camera ISP3**: 27 MB / 300 files / ~12 K LoC → hard but FEASIBLE
> - **Modem ECCCI**: 2.1 MB / 54 .c / ~12 K LoC + Samsung partial ccci_util
>   already in 6.6 → FEASIBLE
> - **Touch**: Confirmed NT36525B Novatek (no longer "unknown")
> - **Connectivity**: Samsung tree has gen4m+gen4m_s1+bt+fm+gps+conninfra
>   already 6.6-ready (superset of our port)
>
> See `docs/PRODUCTION_ROADMAP.md` for realistic 6-month timeline to full
> daily-driver parity.

Audit date: **2026-05-12**. Cross-checked against:
- staged `kernel-6.6/` (1.6 GB, Samsung A055F Linux 6.6.50)
- staged `device-modules/` (323 MB, Samsung kernel_device_modules-6.6)
- staged `vendor-modules/mediatek/kernel_modules/` (284 MB, MTK)
- 4.14 reference `~/aetherx/.../official-realme-rmx3171-family-4.14/` (1.6 GB)
- `device/realme/RMX3171/` Android device tree
- v4 release artifact (102 MB zip, 1976 MTK symbols in vmlinux, 149 .ko)

Priorities:
- **P0** = boots-but-broken or won't-boot.
- **P1** = visible-broken (daily-use blockers: display, touch, audio, charging).
- **P2** = quality-of-life broken (camera, FP, FM, GPU 3D).
- **P3** = nice-to-have or doesn't-matter for daily.

---

## P0 — boot integrity gaps

### P0.1 — DTBO image not built ❌

**Evidence:** `device/realme/RMX3171/BoardConfigA16.mk:22` sets
`BOARD_INCLUDE_DTB_IN_BOOTIMG :=` (empty) → A16 expects separate `dtbo.img`.
`grep BOARD_PREBUILT_DTBOIMAGE` returns nothing.
`find . -name "*dtbo*"` returns nothing.

**Impact:** Stock bootloader on RMX3171 checks dtbo slot. Missing = no overlay
loaded = pinctrl + battery + RMX3171-specific DT nodes inert. Many things
won't probe.

**Fix:** Add `BOARD_KERNEL_DTBOIMAGE_PARTITION_SIZE := 8388608` to
BoardConfigA16.mk + write `scripts/build/pack_dtbo.sh` that packs
`mt6768-rmx3171.dtbo` from board DTS overlay.

---

### P0.2 — `system_dlkm` partition missing from A16 board config ❌

**Evidence:** `grep system_dlkm device/realme/RMX3171/BoardConfigA16.mk`
returns nothing. A16 GKI strict: GKI modules (mt6358 PMIC, mtk-sd, etc.) live
in `/system_dlkm/lib/modules/`. Without partition config, all modules end up
in vendor_dlkm = breaks GKI compliance.

**Impact:** Boots but Google CTS-on-GSI will reject. KMI symbol violation
warnings in dmesg.

**Fix:** Add to BoardConfigA16.mk:
```
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE := 67108864
```
+ split `vendor_dlkm.modules.load` into GKI half + vendor half.

---

### P0.3 — AVB production keys not configured ⚠️

**Evidence:** All `BOARD_AVB_*_KEY_PATH` point at
`external/avb/test/data/testkey_rsa2048.pem`.

**Impact:** Cannot boot on locked-bootloader RMX3171. Unlocked OK (RMX3171
bootloader unlocked-able via `fastboot oem unlock`), but no chain-of-trust on
final image.

**Fix:** Generate production key, document in `docs/SIGNING.md`, swap key paths
in board config.

---

### P0.4 — bootconfig.img not configured ❌

**Evidence:** A16 expects `/proc/bootconfig` populated from
`vendor_bootconfig` partition. `grep BOARD_BOOTCONFIG device/...` returns
nothing.

**Impact:** `androidboot.*` props won't reach init. fastboot-set props
(slot, dm-verity state) won't propagate.

**Fix:** Add `BOARD_BOOTCONFIG := androidboot.hardware=mt6768`
to BoardConfigA16.mk.

---

### P0.5 — KMI ABI allowlist absent ⚠️

**Evidence:** No `abi_gki_aarch64_aether` file. A16 GKI 2.0 requires
allowlisted KMI symbols for vendor modules to bind cleanly.

**Impact:** vendor_dlkm modules may refuse to load with
`Unknown symbol __ksymtab_*` after kernel update.

**Fix:** Generate via `make abi_aether` after a successful build, commit to
`aether-rmx3171/abi/abi_gki_aarch64_aether`.

---

## P1 — visible daily-use gaps

### P1.1 — Display: ilt9881h panel driver not ported ❌

**Evidence:** `aether-rmx3171/ports/TODO/panel-ilt9881h/` has 4.14 source
(Truly + TXD variants, ~600 LoC each) but no 6.6 DRM panel driver landed.
Mainline `drivers/gpu/drm/panel/` has no ilt9881h.

**Impact:** **Black screen on boot.** This is the single biggest blocker.

**Fix:** Port per `aether-rmx3171/ports/TODO/panel-ilt9881h/README.md`.
Translate 4.14 LCM init_setting array → `mipi_dsi_dcs_write_seq` calls in
DRM panel skeleton. Estimated 200 LoC + device test loop.

---

### P1.2 — Touch driver mismatch ⚠️

**Evidence:** `vendor_dlkm.modules.load` includes `goodix_ts.ko` and
`edt_ft5x06.ko`. RMX3171 actual touch panel is **NOVATEK NT36525B**
(`docs/01_hardware_truth.md` — but file not re-checked vs 4.14 evidence).

**Impact:** Touch may not register. Phone unusable without working touch.

**Fix:** Verify touch chip from stock vendor blob:
```
strings vendor/lib*/hw/touch.*.so | grep -iE 'nt365|ft5x|gtx|himax'
```
Then either add `novatek-nt36525b.ko` (port from 4.14) or symlink to closest
mainline driver.

---

### P1.3 — Audio: sia81xx smart PA not ported ⚠️

**Evidence:** `aether-rmx3171/ports/TODO/sia81xx-audio/` has 4.14 source.
6.6 audio works via mt6358 codec alone but speaker is muted/quiet — sia81xx
is the external PA driving the speaker.

**Impact:** Phone calls speakerphone barely audible. Media playback quiet.

**Fix:** Port per `ports/TODO/sia81xx-audio/README.md`. Minimal ASoC codec
~400 LoC.

---

### P1.4 — Battery SOC inaccurate ⚠️

**Evidence:** mt6370 charger module reports voltage-derived SOC (±10%).
gm30 fuelgauge port deferred.

**Impact:** Battery % jumps around. Stock apps think battery low at 40%.
Auto-poweroff at wrong %.

**Fix:** Either real gm30 port (~3000 LoC) or write
`aether_simple_gauge.c` (~400 LoC) using `rmx3171_bat_profile.dtsi` lookup.

---

### P1.5 — Charger curve / fast-charge not configured ⚠️

**Evidence:** `mt6370_charger.ko` loads, but no charging policy from
`<linux/power/mtk_charger.h>` framework. **18W Quick Charge** (9V/2A) requires
PE+ (Pump Express Plus) handshake from 4.14 `mtk_pe.c` (not ported).

**Impact:** Charges at default 5V/2A only (~10W). 18W → ~10W = ~80% slower.

**Fix:** Port PE+ handshake from 4.14 `drivers/power/mediatek/charger/mtk_pe.c`.

---

## P2 — quality-of-life gaps

### P2.1 — Camera: ISP3 framework not present ⚠ (HARD but FEASIBLE — corrected)

**Evidence (corrected):**
- 4.14 `drivers/misc/mediatek/cameraisp/` = **5.7 MB, 42 .c files** (ISP3 framework)
- 4.14 `drivers/misc/mediatek/imgsensor/` = **21 MB, 264 .c files** (28 sensor drivers)
- Total: ~27 MB / ~300 files / **~12 K LoC** (was earlier estimated 50K — wrong)
- RMX3171 sensors: ov13b10 (rear), s5k4h7 (front), gc2375h (macro), ov02a1b (depth)
- Samsung mtkcam ISP8 (Galaxy era) sensors don't match — confirmed no overlap.

**Impact:** No camera (preview / photo) until ported.

**Fix paths** (see `PRODUCTION_ROADMAP.md` Phase 8):
  - **Full path** (~190 h): Port ISP_50 framework + key sensors + match
    proprietary camera HAL. Full daily-driver quality.
  - **V4L2 path** (~70 h): Skip MTK ISP, raw passthrough to userspace libcamera.
    Lower quality but 3× faster to ship.

---

### P2.2 — GPU: Mali Bifrost not yet ported ⚠ (FEASIBLE — corrected)

**Evidence (corrected):**
- 4.14 `drivers/misc/mediatek/gpu/gpu_mali/mali_bifrost/` contains
  **r14/r15/r16/r18/r20/r24/r25p0** — all Bifrost = right family for G52 MC1.
- Samsung vendor-modules' mali_avalon-r49p1 is Valhall = wrong (was the basis
  of earlier "infeasible" claim).
- **r25p0** is most modern Bifrost — best port candidate.

**Impact:** No 3D acceleration until ported. Apps fall back to swiftshader.

**Fix paths** (see `PRODUCTION_ROADMAP.md` Phase 7):
  - **Proprietary path** (~120 h): Port mali_bifrost-r25p0 from 4.14 → 6.6
    KMI. Stable kernel API. Match userspace `libGLES_mali.so` ABI.
  - **Panfrost path** (~140 h): Use mainline `drivers/gpu/drm/panfrost/`.
    Open-source, lower performance, no vendor lock-in.

---

### P2.3 — Fingerprint Goodix kernel driver not ported ❌

**Evidence:** `aether-rmx3171/ports/TODO/goodix-fingerprint/source-goodix/`
has 4.14 GF3208 SPI driver. Userspace HAL exists at
`device/realme/RMX3171/fingerprint/`. No `goodix_fp.ko` built.

**Impact:** Fingerprint unlock disabled. PIN/pattern only.

**Fix:** Port per `ports/TODO/goodix-fingerprint/README.md` (~2500 LoC, char
dev + SPI, no DRM/PMIC coupling — feasible).

---

### P2.4 — FM radio mt6631 not ported ❌

**Evidence:** `aether-rmx3171/ports/TODO/fm-mt6631/source/` has full
4.14 OOT module (kernel_modules/connectivity/fmradio, 1.2 MB). Not built.

**Impact:** No FM radio app.

**Fix:** Port per `ports/TODO/fm-mt6631/README.md`. Out-of-tree module —
build doesn't gate kernel, safe to iterate.

---

### P2.5 — Cellular modem (ECCCI) absent ⚠ (FEASIBLE — corrected)

**Evidence (corrected):**
- 4.14 `drivers/misc/mediatek/eccci/`: **2.1 MB, 54 .c files** (~12 K LoC,
  was earlier estimated 80K — wrong)
- Samsung device-modules already has partial port:
  `device-modules/drivers/misc/mediatek/ccci_util/` (5 files, 6.6-ready)
- Modem firmware (md1img.img + md1dsp.img) extractable from stock vendor.

**Impact:** No cellular calls or mobile data until ported.

**Fix paths** (see `PRODUCTION_ROADMAP.md` Phase 9):
  - Port ECCCI framework (~60 h) + integrate signed modem .img blobs (~16 h)
    + link vendor RIL HAL (~24 h) + APN/SIM/VoLTE (~24 h) + test (~16 h).
  - **Total ~140 h** (~4 weeks solo).
  - **Hardest realistic path** in the roadmap — leave for phase 9 of 10.

---

## P3 — optional / deferred

### P3.1 — clk-mt6768 full clock driver ❌
Bootloader configures clocks. DTS fixed-clocks workaround sufficient. See
`ports/TODO/clk-mt6768/README.md`.

### P3.2 — Camera flash (LEDS_MT6370_FLASH) ❌
`CONFIG_LEDS_MT6370_FLASH=y` set but no torch sysfs wired in init.

### P3.3 — Vibrator (haptic motor) ❌
RMX3171 stock uses `mt6358-vibrator` driver. Not in our vendor_dlkm list.

### P3.4 — NFC ❌ (RMX3171 has no NFC chip — irrelevant)

### P3.5 — IR blaster ❌ (RMX3171 has no IR — irrelevant)

---

## Build / packaging gaps

### B.1 — No `pack_dtbo.sh` ❌

No script to convert `mt6768-rmx3171-overlay.dts` → `dtbo.img`.

**Fix:** Add `scripts/build/pack_dtbo.sh` using
`mkdtimg cfg_create dtbo.img dtbo.cfg`.

### B.2 — No `build_release.sh` end-to-end ❌

Current `aether-rmx3171/build/build_aether_6_6.sh` only builds kernel Image.
Doesn't pack AnyKernel, dtbo, vbmeta sign, or upload to GH Releases.

**Fix:** Add `scripts/release/build_release.sh` orchestrating:
  1. kernel build → Image.gz
  2. dtbo build → dtbo.img
  3. AnyKernel pack → AETHER_*.zip
  4. SHA256 + GPG sign
  5. `gh release create`.

### B.3 — No `pack_super.sh` ❌

`PRODUCT_BUILD_SUPER_PARTITION := false`. Custom super.img build path absent.

**Fix:** Add `scripts/build/pack_super.sh` using `lpmake` for users wanting
full system+vendor reflash.

### B.4 — No `sign_vbmeta.sh` ❌

Test keys baked in. No production sign path.

**Fix:** Add `scripts/release/sign_vbmeta.sh` calling `avbtool make_vbmeta_image`.

### B.5 — KernelSU version pinning unclear ⚠️

`kernel-6.6/KernelSU/Cargo.toml` exists but no version recorded in repo docs.

**Fix:** Add KSU version + commit SHA to `docs/STATUS.md`.

---

## Userspace / vendor / blob gaps

### U.1 — VENDOR_BLOBS_REQUIRED.md absent ❌

`device/realme/RMX3171/proprietary-files.txt` lists **3457 blob files**.
No documentation of which are critical vs optional, or how to extract from
stock.

**Fix:** Categorize into `docs/VENDOR_BLOBS.md` — boot-critical vs camera vs
audio vs optional.

### U.2 — Firmware files not staged ❌

Stock vendor needs:
- `WIFI_RAM_CODE_MT6768.bin`
- `BT_RAM_CODE_MT6768.bin` (or similar)
- `GPS_FW_MT6768.bin`
- `mt6358-firmware.bin` (audio DSP)
- Modem images (md1img.img, md1dsp.img — irrelevant since no cellular)

**Fix:** Add extraction script `scripts/extract_blobs.sh` pulling from
mounted stock vendor.img. Document in `docs/VENDOR_BLOBS.md`.

### U.3 — RIL / radio HAL stubs ❌

No `android.hardware.radio@*` in `device.mk`. Cellular wouldn't work even
with modem driver.

**Fix:** Won't fix (no modem driver anyway).

### U.4 — Sensor calibration data not extracted ⚠️

Accel/gyro/mag need per-device calibration from `/persist/sensors/calibration_*`
on stock partition. Without it, compass spins, screen rotation laggy.

**Fix:** Add `scripts/extract_calibration.sh` to read from mounted
`/persist` of stock device.

### U.5 — Audio HAL routing missing sia81xx PA pass ⚠️

`device/realme/RMX3171/audio/audio_policy_configuration.xml` exists. Likely
missing sia81xx PA enable in speaker path (since driver isn't ported).

**Fix:** Add sia81xx route once driver lands.

---

## Documentation gaps

### D.1 — No FLASHING.md (user guide) ❌
### D.2 — No PORTING.md (community contributor onboard) ❌
### D.3 — No HARDWARE_PINOUT.md ❌
### D.4 — No BOOT_FAILURE_TRIAGE.md ❌ (post-install help)
### D.5 — Stale `aether-rmx3171/docs/` (empty) ❌

---

## Summary stat

| Priority | Count | Estimated effort |
|---|---:|---|
| P0 boot integrity | 5 items | 1 week scripted + 1 week build/test |
| P1 daily-use | 5 items | 2 weeks (panel = biggest) |
| P2 quality-of-life | 5 items | 4–8 weeks (camera/GPU = hardest) |
| P3 optional | 5 items | 1–2 weeks total |
| Build pipeline | 5 items | 3–5 days |
| Userspace | 5 items | 1 week |
| Docs | 5 items | 2–3 days |

**Realistic minimum-viable daily-driver path:**
- P0.1 (dtbo), P0.2 (system_dlkm), P0.4 (bootconfig)
- P1.1 (panel), P1.2 (touch verify), P1.3 (sia81xx)
- B.1 (dtbo script), B.2 (release pipeline)
- D.1 (flash guide)

That's **9 items**, ~2 weeks engineering + 2 weeks device-test iteration.

**WiFi + BT + KernelSU + NetHunter base is already working** (149 modules in v4).

**Cellular + camera + 3D GPU = accept as missing** for indefinite future.
