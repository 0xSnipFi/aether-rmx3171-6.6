# Android 16 bring-up notes — RMX3171

What's specifically different about A16 (Android 16) vs RMX3171's stock A11.
Use this as a checklist against `device/realme/RMX3171/BoardConfigA16.mk`.

## A16 partition layout requirements

| Partition | A16 status | Our state |
|---|---|---|
| `boot` | header v4, contains generic ramdisk + kernel | configured (`BOARD_BOOT_HEADER_VERSION := 4`) |
| `init_boot` | A16 mandatory; first-stage init + ramdisk | configured (`BOARD_AVB_INIT_BOOT_*`) |
| `vendor_boot` | header v4; vendor ramdisk + DTB | configured (`BOARD_AVB_VBMETA_VENDOR_BOOT`) |
| `vendor_dlkm` | mounted by 2nd-stage init at /vendor_dlkm | configured (`BOARD_USES_VENDOR_DLKMIMAGE := true`) |
| `system_dlkm` | A16 GKI-strict; mounted at /system_dlkm | **MISSING** (P0.2 in MISSING.md) |
| `vendor_kernel_boot` | optional, kernel-only ramdisk | not used (kernel in boot) |
| `dtbo` | overlay DT | **NOT BUILT** (P0.1 in MISSING.md) |
| `vbmeta` | root of trust | configured with test keys |
| `vbmeta_system` | chains system + system_ext + product | configured |
| `vbmeta_vendor` | chains vendor + vendor_dlkm | configured |
| `super` | dynamic partition holding all of above | configured (`BOARD_SUPER_PARTITION_SIZE := 6685720576`) |

## A16 init changes

A16 deprecates several things from older Android:

| Deprecated | Replacement | Our state |
|---|---|---|
| `/proc/cmdline` for boot props | `/proc/bootconfig` from bootconfig.img | **MISSING bootconfig.img** (P0.4) |
| Legacy `init.rc` `class_start` racing | `class_start_async` | check `init.aether_root.rc` |
| HIDL HAL (`@1.0`, `@2.0` services) | AIDL HAL (versioned interfaces) | fingerprint still HIDL — works in A16 with shim |
| `/persist` as separate partition | mounted from super | confirm fstab.mt6768.a16 |
| `ro.product.first_api_level` < 30 | must be ≥ 34 for A16 | check `aether_RMX3171.mk` |
| `androidboot.*` kernel cmdline | `androidboot.*` in bootconfig | won't propagate without P0.4 fix |

## A16 GKI 2.0 requirements

A16 expects:

1. **GKI kernel image** (one Image, multiple vendor_dlkm) — we deviate
   (custom kernel build) but stay KMI-compatible.
2. **KMI symbol allowlist** — `abi_gki_aarch64_aether` file. **MISSING.**
3. **APEX** updatable modules — `updatable_apex.mk` inherited; payload not
   yet validated.
4. **dm-verity** on system + vendor — enabled via AVB.
5. **dm-default-key** for FBE — fstab has `inlinecrypt` flag.
6. **fs-verity** for app signing — enabled via `f2fs_fsverity` (kernel
   `CONFIG_FS_VERITY=y` confirmed in overlay).

## Userspace bring-up gates

Before flashing, verify:

```bash
# In device/realme/RMX3171/aether_RMX3171.mk, must have:
PRODUCT_SHIPPING_API_LEVEL := 34   # or 35 for A16
PRODUCT_BUILD_PROP_OVERRIDES += ro.product.first_api_level=34
```

VINTF compatibility:

```bash
# device/realme/RMX3171/configs/manifests/manifest.xml must list:
# android.hardware.boot @1.2
# android.hardware.fastboot @1.1
# android.hardware.health @2.1
# android.hardware.biometrics.fingerprint @2.1
# android.hardware.audio @7.0 or @AIDL
# android.hardware.power @AIDL
# (and many more — verify with `vintf check`)
```

## SELinux on A16

A16 tightens domain definitions. Our 21 .te files in
`device/realme/RMX3171/sepolicy/private/` cover:

- `hal_fingerprint_RMX3171.te`
- `mtk_hal_mms.te` (MTK media-related)
- `domain.te`, `init.te`, `system_app.te`
- `hal_power.te`, `kpoc_charger.te`, `perf_profile.te`
- `radio.te`, `property*`, `file*`, `service_contexts`

**Missing on A16:**
- `hal_camera_realme.te` (camera HAL not running anyway)
- `hal_health_storage.te` (A16 requires UFS or eMMC health AIDL)
- `hal_audiocontrol.te` for sia81xx pass (audio amp HAL)
- `hal_thermal.te` (thermal AIDL on A16)

## A16 known compat issues for old MTK platforms

1. **Old binder transactions**: A16 binder requires `vndk` headers v34. Stock
   RMX3171 blobs (A11 vndk v30) need shims — `libshims/` dir handles this.
2. **VNDK enforcement**: A16 sets `vndk.lite` in VNDK contexts. Verify
   `libshims/Android.bp` lists every blob's missing symbol.
3. **Strict mode for fstab**: A16 expects `metadata_csum_seed` flag on f2fs
   userdata. Check `fstab.mt6768.a16`.
4. **APEX disable**: if any APEX module ABI breaks, set
   `PRODUCT_BUILD_APEX_PACKAGES := false` in aether_RMX3171.mk.

## Verifiable boot test path

After flash, dmesg gates (in order):

```
1. [    0.000000] Linux version 6.6.129-AETHER-X-RMX3171-A16+
2. [    0.123456] OF: fdt: Machine model: Realme RMX3171
3. [    0.234567] mt6358-soc-pmic-wrapper: probe OK
4. [    0.345678] mtk-sd 11230000.mmc: ... → /dev/mmcblk0 ready
5. [    1.234567] init: First stage init
6. [    2.345678] init: Mounting /vendor
7. [    3.456789] init: Mounting /vendor_dlkm (208 modules loaded)
8. [    5.678901] init: Boot complete
```

If any gate fails, log to GitHub Issue with `boot_failure` template.

## A16 vs A15 backport gotchas

- A16 ships `init/first_stage_init.cpp` expecting `/dev/loop-control` early
  — our overlay has `CONFIG_BLK_DEV_LOOP=y` ✓.
- A16 enforces `__counted_by` annotation — clang-18+ required. Our build
  uses clang-r510928 ≥ clang-18 ✓.
- A16 dropped `system/extras/su` — replaced by KernelSU manager APK.
- A16 introduces `system_ext_dlkm` for system_ext modules — not yet relevant.

## Open questions before claiming "A16 ready"

1. Does Realme firmware-fastboot accept boot.img v4 ? (only known via flash test)
2. Does our fstab.mt6768.a16 correctly handle dm-default-key on /userdata?
3. Will stock RMX3171 vendor SELinux contexts match our private .te files?
4. Will A16 SurfaceFlinger negotiate panel timings from our DRM panel driver
   once ported?

All require physical device + community test.
