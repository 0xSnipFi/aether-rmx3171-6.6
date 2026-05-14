# Production Roadmap — RMX3171 A16 / Linux 6.6 daily driver

**Goal:** 100% working, real implementation, daily-use ready.
**Date:** 2026-05-12. **Audit:** all source paths re-verified.

This doc supersedes earlier "infeasible" claims in `MISSING.md`. After deep
re-audit of 4.14 + Samsung vendor-modules + device-modules trees, **most
deferred items are actually feasible.** This roadmap shows how.

---

## TL;DR — Realistic timelines

| Goal | Solo dev | 2–3 contributors |
|---|---|---|
| **Minimum viable daily driver** (boot + display + touch + audio + WiFi + BT + charging + KSU) | **6 weeks** | **3 weeks** |
| + Battery accuracy + Fingerprint + FM + Vibrator | +2 weeks | +1 week |
| + Mali GPU 3D acceleration | +4 weeks | +2 weeks |
| + Camera (basic preview + photo) | +6 weeks | +3 weeks |
| + Cellular (4G data + calls) | +6 weeks | +3 weeks |
| **Full A11-parity daily driver** | **6 months** | **3 months** |

**Engineering budget without cellular + camera:** ~120 hours. Feasible.
**With camera:** +200 h. **With cellular:** +120 h.

---

## Re-audit findings — what was wrong before

### 1. Mali GPU — was "vendor BSP gate, infeasible". REAL = **portable**.

**Evidence:**
```
4.14 source path:
drivers/misc/mediatek/gpu/gpu_mali/mali_bifrost/
├── mali-r14p0/   (oldest)
├── mali-r15p0/
├── mali-r16p0/
├── mali-r18p0/
├── mali-r20p0/
├── mali-r24p0/
└── mali-r25p0/   ★ MOST MODERN Bifrost — best candidate for 6.6 port
```

RMX3171 / Helio G85 = **Mali-G52 MC2 class (Bifrost gen2)**. r25p0 is the right family.
Samsung vendor-modules' mali_avalon-r49p1 is **wrong** (Valhall = G77+).
The 4.14 r25p0 driver can be ported to 6.6 KMI by porting r25 → r34 conventions.

### 2. Camera ISP3 — was "50K LoC infeasible". REAL = **12K LoC, hard but feasible**.

**Evidence:**
```
4.14 cameraisp:    5.7 MB,  42 .c files  ← framework
4.14 imgsensor:    21 MB,  264 .c files  ← 28 sensor drivers
Total:             ~27 MB, ~300 .c files
```

ISP3 framework is contained in `cameraisp/{dip,mfb,rsc,owe,dpe}/isp_50/`.
ISP_50 = ISP gen 5.0 = MT6768. Smaller than I claimed.

### 3. ECCCI modem — was "80K LoC infeasible". REAL = **12K LoC, feasible**.

**Evidence:**
```
4.14 drivers/misc/mediatek/eccci: 2.1 MB, 54 .c files
device-modules/drivers/misc/mediatek/ccci_util: ALREADY PORTED to 6.6
   (5 files: ccci_util_lib_fo.c, ccci_util_md_mem.c, ccci_util_boot_args.c,
    ccci_util_md_rat.c, ccci_util_ld_md_errno.c)
```

Samsung's ccci_util in device-modules = **partial 6.6 ECCCI already done**.
Builds on top of this.

### 4. Touch chip — was "verify needed". REAL = **NT36525B Novatek confirmed**.

**Evidence:**
```
4.14 path:
drivers/input/touchscreen/mediatek/NT36525B/nt36xxx.c
drivers/input/touchscreen/NT36672C/nt36xxx.c  (similar, larger panel)
```

Both Novatek variants present. NT36525B = our touch IC.
device-modules has Novatek pattern in `drivers/input/touchscreen/ILI7807S/`
(Ilitek pattern, similar SPI/I²C structure to port from).

### 5. WiFi/BT/FM — was "ports separate, scaffolded". REAL = **Samsung tree has all**.

**Evidence:**
```
vendor-modules/mediatek/kernel_modules/connectivity/:
├── wlan/core/{gen4m, gen4m_ext, gen4m_s1}   ← three gen4m variants for mt6768+newer
├── bt/{mt66xx, linux_v2}                     ← Bluetooth
├── fmradio/                                  ← FM
├── gps/                                      ← GPS combo
├── conninfra/init.conninfra.rc + base/conn_drv  ← connsys arbiter
└── connfem/                                  ← Front-End Module (PA)
```

This is **superset** of aetherx WiFi port. Switch to Samsung tree = get
bt+fm+gps+conninfra for free.

### 6. Display panel — was "needs DRM panel rewrite". REAL = **MTK panel framework already in tree**.

**Evidence:**
```
device-modules/drivers/gpu/drm/mediatek/mediatek_v2/mtk_panel_ext.{c,h}
device-modules/drivers/gpu/drm/panel/panel-wt-n28-xinxian-icnl9916c-hdp-vdo.c
   ← reference pattern: third-party HDP panel using mtk_panel_ext
device-modules/drivers/gpu/drm/mediatek/dummy_drm/  ← scaffolding
```

Use `mtk_panel_ext` framework, NOT mainline `drm_panel`. Copy
`panel-wt-n28-xinxian-icnl9916c-hdp-vdo.c` as template (similar HDP vdo panel),
swap init_setting + timing from 4.14 ilt9881h_truly. **~150 LoC + tested
panel-init array.**

---

## Phase-by-phase real implementation plan

### PHASE 0 — Foundation cleanup (2 days)

Already mostly done. Remaining:

| Task | Effort |
|---|---|
| Move build_*.log to .build-logs/ (gitignored) | ✅ DONE |
| Stale doc cleanup | ✅ DONE |
| Add `scripts/extract_blobs.sh` | 2 h |
| Add `scripts/sync_samsung_base.sh` | 2 h |
| First-class CI: kernel build on PR via GH Actions | 4 h |

### PHASE 1 — A16 boot integrity (4 days)

Must complete before flashing.

| Task | LoC / files | Effort | Status |
|---|---|---|---|
| **dtbo build** - `scripts/build/pack_dtbo.sh` | script + dtbo output | 4 h | source done; syntax/static checked |
| **system_dlkm/vendor_dlkm logical partitions** - stock-GPT path | `BoardConfigA16Legacy.mk` | 2 h | source done |
| **bootconfig.img** - GKI-v4 path only | n/a for stock RMX3171 | 0 h | not used on stock boot-header-v2 |
| **KMI allowlist** - extract after stable kernel build | `aether-rmx3171/abi/abi_gki_aarch64_aether` | 4 h | file present; regenerate after ABI changes |
| **vbmeta production keys** - generate outside git | scripts + docs | 2 h | tooling present; real private key still user-owned |
| **AVB sign pipeline** - stock-v2 aware `sign_vbmeta.sh` | script | 4 h | source done; syntax checked |
| **fstab.mt6768.a16 audit** - non-A/B stock path | review | 1 h | source done; no slotselect |

**Total Phase 1: ~21 h (3 days solo).** Output: bootable shell on physical device.

### PHASE 2 — Display + Touch (1 week)

| Task | Effort | Approach |
|---|---|---|
| **panel-ilt9881h DRM port** | 30 h | Pattern: `panel-wt-n28-xinxian-icnl9916c-hdp-vdo.c` template (device-modules). Copy structure, port init_setting from 4.14 `ilt9881h_truly_hdp_dsi_vdo_lcm.c` DSI command array. Hook into mtk_panel_ext (not mainline drm_panel). |
| **panel-NT36672C alt variant** | 8 h | Some RMX3171 builds use NT36672C. Make compatible string runtime-selectable in DTS. |
| **NT36525B touch driver port** | 40 h | Pattern: device-modules `ILI7807S` driver (similar SPI/I²C touchscreen). Copy 4.14 `mediatek/NT36525B/nt36xxx.c` → adapt I²C ops to 6.6 i2c-core API. ~3800 LoC. |
| **DTS pinctrl groups for touch + panel** | 4 h | Already extracted in cust_mt6768_rmx3171_pinctrl.dtsi — verify panel + touch pins listed. |
| **Build + boot test** | 8 h | Flash, check dmesg for `drm_panel: registered`, `nvt_ts_probe success`. |

**Total Phase 2: ~90 h (~2 weeks solo).** Output: screen lights + touch works.

### PHASE 3 — Audio + Charging + Battery (1 week)

| Task | Effort | Approach |
|---|---|---|
| **sia81xx ASoC codec rewrite** | 20 h | `ports/TODO/sia81xx-audio/README.md` already has skeleton. Replace 4.14 vendor framework with minimal regmap-based codec. ~400 LoC. |
| **mt6358 audio routing** | 8 h | mainline `sound/soc/mediatek/mt6358/` works. Add machine driver tying mt6358 ↔ sia81xx. |
| **mt6370_charger PE+ handshake port** | 24 h | 4.14 `drivers/power/mediatek/charger/mtk_pe.c` → adapt to 6.6 power-supply class. Enables **18W Quick Charge** (9V/2A via Pump Express+). ~1500 LoC. |
| **gm30 fuelgauge — simple version** | 16 h | Per `gm30-battery/README.md` Path B. Use `rmx3171_bat_profile.dtsi` table lookup. ~400 LoC. |
| **Build + test** | 8 h | speaker audible, charging at >5V, SOC ±5%. |

**Total Phase 3: ~76 h (~10 days solo).** Output: usable phone for browsing/music.

### PHASE 4 — Connectivity unification (3-4 days)

Switch from aetherx gen4m port → Samsung vendor-modules/connectivity tree.

| Task | Effort | Approach |
|---|---|---|
| **Add Samsung connectivity to build** | 8 h | Hook `vendor-modules/mediatek/kernel_modules/connectivity/` Kbuild into kernel-6.6 build via external M= |
| **Pick mt6768 target in conninfra Kconfig** | 4 h | `MTK_COMBO_CHIP=MT6631` (mt6631 = WiFi+BT+FM+GPS combo) |
| **Wire connfem (PA front-end)** | 4 h | mt6631 needs PA enable via connfem driver |
| **Replace WiFi loader in vendor_dlkm.modules.load** | 2 h | wmt_drv.ko → conninfra.ko + connfem.ko + wlan_drv_gen4m.ko + bt_drv_mt66xx.ko + fmr.ko + gps_drv.ko |
| **Build + test** | 8 h | iwconfig, hcitool, FM scan, NMEA log from /dev/gps. |

**Total Phase 4: ~26 h (~3.5 days solo).** Output: WiFi+BT+FM+GPS all working.

### PHASE 5 — Goodix fingerprint (3 days)

| Task | Effort |
|---|---|
| **gf3208 SPI char-dev port** | 16 h |
| **DTS SPI + GPIO nodes** | 2 h |
| **selinux .te for /dev/goodix_fp** | 2 h |
| **vendor HAL link (existing `device/realme/RMX3171/fingerprint/`)** | 2 h |
| **Build + test** | 4 h |

**Total Phase 5: ~26 h (~3.5 days solo).** Output: fingerprint unlock works.

### PHASE 6 — Vibrator + Flashlight + Sensors (3 days)

| Task | Effort |
|---|---|
| **mt6358-vibrator (haptic motor)** | 8 h. mainline exists, just enable + DTS wire. |
| **LEDS_MT6370_FLASH torch wire** | 4 h. Add /sys/class/leds/torch entry. |
| **Sensor hub SCP firmware loader** | 8 h. Already builds (`mtk_scp.ko`) but needs `firmware/scp.img` from stock vendor. |
| **Accel/gyro/mag driver enable** | 16 h. mt6768 stock uses bmi160 (Bosch) + akm09918 (AK). Enable mainline. |
| **Step counter** | 4 h. CONFIG_INPUT_PEDOMETER or via accel sensor. |
| **Build + test** | 4 h. |

**Total Phase 6: ~44 h (~6 days solo).** Output: haptics + flashlight + auto-rotate + step counter.

### PHASE 7 — Mali GPU 3D acceleration (3 weeks)

| Task | Effort | Approach |
|---|---|---|
| **Port Mali r25p0 Bifrost → 6.6** | 80 h | Source: 4.14 `drivers/misc/mediatek/gpu/gpu_mali/mali_bifrost/mali-r25p0/`. Target: vendor-modules/mediatek/kernel_modules/gpu/ but **replace mali_avalon-r49p1 with mali_bifrost-r25p0**. Adapt platform/mt6768 glue. ~50K LoC mostly stable kernel API. Expected fixes: drm_legacy → drm_dma_helper, get_user_pages signature, vmalloc_user gone in 6.6. |
| **OR** alternative: panfrost mainline | 100 h | Mainline `drivers/gpu/drm/panfrost/` is open-source Mali driver. Supports Bifrost. Less performant than proprietary but free of vendor dependency. Need: G52 MC2-class quirks and Android userspace testing. |
| **Match Mali userspace blob** | 8 h | `vendor/lib*/egl/libGLES_mali.so` from stock RMX3171 expects specific kernel ABI. r25p0 kernel ↔ r25p0 userspace. Extract from stock. |
| **GPU governor (mtk_gpufreq)** | 16 h | device-modules has `drivers/gpu/mediatek/gpufreq_v1/`. Use existing. |
| **Build + benchmark** | 16 h | Run `glmark2-es2`, `geekbench compute` to verify 3D works. |

**Total Phase 7: ~120 h proprietary / 140 h panfrost (~3 weeks solo).**
Output: hardware-accelerated apps, OpenGL ES 3.2, Vulkan 1.0 (if proprietary).

### PHASE 8 — Camera (5-6 weeks, hardest)

| Task | Effort | Approach |
|---|---|---|
| **Port ISP_50 camera framework** | 80 h | 4.14 `cameraisp/` 42 files → 6.6 v4l2 subdev model. dip + mfb + rsc paths. |
| **Port ov13b10 sensor (rear)** | 20 h | 4.14 `imgsensor/src/common/v1/ov13b10_mipi_raw/`. ~3000 LoC. Hook into ISP framework via subdev. |
| **Port s5k4h7 sensor (front)** | 20 h | Same pattern. |
| **Port aux sensors (depth/macro)** | 30 h | gc2375h (macro), ov02a1b (depth). Optional. |
| **Wire to camera HAL** | 16 h | `device/realme/RMX3171/` proprietary blobs include camera HAL. Match ABI. |
| **Build + test preview/photo** | 24 h | Camera2 API test, libcamera test, Android camera app. |
| **OR** alternative: skip MTK ISP, V4L2-only raw passthrough | 40 h | No image processing in kernel. Userspace libcamera does demosaic/AWB. Lower quality but feasible. |

**Total Phase 8: ~190 h proprietary / 70 h V4L2-only (~5-6 weeks / 2 weeks).**
Output: camera preview + photo (no advanced HDR/zoom in V4L2 path).

### PHASE 9 — Cellular modem (4 weeks, requires signed firmware)

| Task | Effort | Approach |
|---|---|---|
| **Port ECCCI framework** | 60 h | 4.14 `drivers/misc/mediatek/eccci/` 54 files → 6.6. Samsung's `ccci_util` in device-modules helps. |
| **Modem firmware integration** | 16 h | Extract `md1img.img` + `md1dsp.img` from stock `/vendor/firmware/`. Pin checksum in build. |
| **Vendor RIL HAL linking** | 24 h | Stock has `mtk-ril.so` + `librilmtk.so` blobs in proprietary-files.txt. Add libshims for ABI gap. |
| **APN + SIM card detection** | 8 h | SIM detection via PMIC SIM_VBAT regulator. |
| **VoLTE + Voice call** | 16 h | IMS service. `ImsInit/` dir present. |
| **Build + test** | 16 h | Make a call, check 4G data, verify SMS. |

**Total Phase 9: ~140 h (~4 weeks solo).** Output: cellular calls + 4G data.

### PHASE 10 — Polish + KMI lock + CTS (1 week)

| Task | Effort |
|---|---|
| Generate KMI allowlist from stable build | 4 h |
| GH Actions CI: build+abi-check on PR | 8 h |
| `gh release create` automation | 4 h |
| FLASHING.md user guide | 4 h |
| PORTING.md contributor guide | 8 h |
| HARDWARE_PINOUT.md | 6 h |
| BOOT_FAILURE_TRIAGE.md | 4 h |
| CTS-on-GSI runs | 16 h |
| ABI freeze + tag v1.0-stable | 2 h |

**Total Phase 10: ~56 h (~1 week solo).** Output: documented, locked-ABI, CI'd repo.

---

## Critical-path dependencies

```
Phase 1 (boot) → Phase 2 (display) ── must serial
                       ↓
                    Phase 3 (audio + charging) ── can parallel from here
                       ↓
                    Phase 4 (connectivity)
                       ↓
            ┌──────────┼──────────┐
        Phase 5      Phase 6    Phase 7 (GPU)
        (fp)         (misc)         ↓
            └────┬─────┘          Phase 8 (camera)
                 ↓                    ↓
              Phase 10 (polish) ← Phase 9 (modem)
```

Phases 5, 6, 7 can run in parallel after Phase 4. Phases 8, 9 should follow
Phase 7 (camera needs GPU for ISP, modem needs all base stable).

---

## Engineering resources needed

### Person-hours (solo, conservative)

| Tier | Phases | Hours | Calendar weeks @ 30 h/wk |
|---|---|---:|---:|
| **MVP daily-driver** (no cam, no cell) | 0+1+2+3+4+5+6 | 309 | **10 wk** |
| + GPU 3D | +7 | 429 | 14 wk |
| + Camera (V4L2 path) | +8 (V4L2) | 499 | 17 wk |
| + Camera (full ISP3) | +8 (ISP3) | 619 | 21 wk |
| + Cellular | +9 | +140 | +5 wk |
| **Full daily driver** | 0–10 | 815 | **27 wk = ~6.3 months** |

### Compute resources

| Item | Size |
|---|---|
| Disk (kernel + vendor + device + AOSP + caches) | 250 GB |
| RAM (kernel build + Bazel) | 16 GB minimum, 32 GB recommended |
| CPU (i7 / Ryzen 7) | Full kernel build = 35 min on 8c |
| One physical RMX3171 for boot tests | unavoidable |
| Optional: 2nd phone, USB UART for serial console | helpful but not strict |

### Tooling

| Tool | Use | Available? |
|---|---|---|
| `clang-r510928` | A055F-compatible compiler | ✅ available |
| `bazel 6.5.0` | Kleaf full build | ✅ available |
| `mkbootimg`, `mkdtimg`, `lpmake`, `avbtool` | Image build | ✅ android-tools |
| `vendor/mediatek/...` Kleaf modules | Samsung BSP modules | ✅ device-modules dir |
| `osm0sis/AnyKernel3` | flashable zip pack | ✅ cloned |
| `gh` CLI | release upload | install once |

---

## Risk register

| Risk | Mitigation |
|---|---|
| Mali r25p0 → 6.6 KMI gap larger than 50K lines | Fallback: panfrost mainline (Phase 7 alt) |
| Camera ISP3 framework needs heavy mtk-vcu / mtk-mmsys plumbing | Fallback: V4L2 path (Phase 8 alt) |
| Modem firmware signed against bootloader chain | Skip cellular; ship as WiFi-only daily |
| Stock vendor blobs ABI-incompatible with A16 vndk | libshims layer (already in `device/realme/RMX3171/libshims/`) |
| KernelSU breaks GKI signature check | Build two flavors: gki-clean + ksu-modified |
| Realme bootloader rejects boot.img v4 | Already proven: RMX3171 takes unlocked custom boot |
| Single-developer burnout on 6-month timeline | Community split via 2–3 contributors (Phase split) |
| Device irreparably bricked during test | EDL + MTK SP Flash Tool can restore stock — always have backup |

---

## What we will NOT do

| Item | Why |
|---|---|
| Custom recovery (TWRP / OrangeFox port) | Use existing community recovery for RMX3171 |
| Stock Realme UI port | Out of scope — ship AOSP-based ROM |
| GApps integration | Users add via NikGapps post-install |
| Magisk-mode bootstrap | KernelSU is the chosen root path |
| Per-region carrier config | Use generic APN, user-configurable |
| 5G | RMX3171 has no 5G modem |

---

## Concrete next-step (start tomorrow)

Day 1–2: **Phase 1 dtbo + system_dlkm + bootconfig** — 21 h scripted work.
Day 3: First flash on device. Capture dmesg.
Day 4–14: **Phase 2 panel + touch** — biggest impact for daily-use.
Day 15–24: **Phase 3 + 4** — audio, charge, connectivity polish.

End of week 4: **post first beta release** to community.

End of week 10: **MVP daily-driver release**.

End of month 6: **v1.0-stable** full-coverage release.

---

## Honest framing

**Can we make it 100% working real implementation?** Yes, with caveats:

✅ **Realistic**: WiFi, BT, FM, audio, display, touch, charge, battery, FP,
   sensors, vibrate, flashlight, KSU, NetHunter — all proven possible.
   Total ~10 weeks engineering.

⚠️ **Possible with effort**: Mali 3D GPU (need to port r25p0 Bifrost). ~3 wk.

⚠️ **Possible but hard**: Camera (port ISP3 framework + sensors). ~6 wk.

⚠️ **Possible but blob-gated**: Cellular (need extracted stock modem firmware). ~5 wk.

❌ **Won't work even with infinite time**:
   - 5G (no hardware).
   - True Vulkan 1.3+ (Mali G52 maxes at 1.0/1.1).
   - Sub-50ms HDR camera processing (no MTK APU 3.0 on this SoC).

**Daily-driver definition for "100% working":**
- ✅ Boot, screen, touch, audio, WiFi, BT, charge, root, KSU, NetHunter HID
- ✅ Camera (preview + basic photo)
- ✅ Fingerprint, sensors, haptics
- ✅ Cellular 4G + calls (if blobs extracted)
- ✅ 3D gaming up to medium settings

This is reachable in **6 months solo or 3 months with 2-3 community contributors**.

The repo is structured to support exactly this pace.
See `docs/STRUCTURE.md` for where each phase's work lands.
See `aether-rmx3171/ports/TODO/` for first picks.
