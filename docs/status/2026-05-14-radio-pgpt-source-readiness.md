# Status snapshot - 2026-05-14

## Scope

This snapshot records the RMX3171 Android 16 / Linux 6.6 source state after the
radio blob skip and PGPT strategy audit.

## Radio / modem extraction

Radio-critical blobs are no longer allowed to be skipped in the proprietary
lists or extraction script.

Source-level changes verified:

- `device/realme/RMX3171/proprietary-files.txt` lists:
  - `vendor/firmware/md1img.img`
  - `vendor/firmware/md1dsp.img`
  - `vendor/bin/hw/mtkfusionrild`
  - `vendor/lib64/libmtk-ril.so`
  - `vendor/etc/apdb/APDB_MT6768_S01__W2044`
  - `vendor/etc/apdb/APDB_MT6768_S01__W2044_ENUM`
  - OPLUS radio/appradio VINTF manifests and framework jars
- `device/realme/RMX3171/proprietary-files-system.txt` no longer skips the
  OPLUS radio/IMS/appradio framework jars or `OppoSimSettings.apk`.
- `scripts/extract_blobs.sh` copies modem firmware, RIL, IMS, APDB and OPLUS
  radio blobs into `vendor/realme/RMX3171/proprietary/...`.
- `scripts/extract_blobs.sh` also mirrors firmware into
  `aether-rmx3171/firmware/...` for kernel bring-up.
- `device/realme/RMX3171/init/fstab.mt6768.a16` exposes physical
  `/dev/block/by-name/md1img`.
- The captured RMX3171 `block-by-name.txt` has no physical `md1dsp` entry, so
  `md1dsp.img` is kept as a vendor firmware blob instead of a fstab partition.

Static verification:

- grep for skipped radio/RIL/IMS/modem entries in proprietary lists returned no
  remaining matches.
- `scripts/extract_blobs.sh` passes bash syntax check.

Hardware status:

- ECCCI/RIL source packaging is prepared.
- SIM attach, calls, LTE data and VoLTE are still not hardware-proven until a
  physical RMX3171 boot log and radio logcat are captured.

## PGPT / Android 16 partition strategy

Production default remains stock RMX3171 PGPT:

- physical `boot`
- physical `dtbo`
- physical `super`
- physical `md1img`
- no physical `md1dsp` by-name entry in the captured stock partition table
- no physical `vendor_boot`
- no physical `init_boot`
- no physical `vendor_dlkm`
- no physical `system_dlkm`
- no A/B slot suffix

Android 16 module separation is handled inside custom `super.img` by logical
`vendor_dlkm` and `system_dlkm`. This keeps the build Android-16-shaped without
requiring risky PGPT remapping.

PGPT remapping is not a production default. Partition sizes matter, and a wrong
PGPT/SGPT edit can hard-brick the device or damage NVRAM/NVDATA/PERSIST. Even
if physical `vendor_boot` or `init_boot` partitions are added, stock RMX3171 LK
is still a boot-header-v2 loader and may ignore them.

## Honest readiness

The source tree is closer to a publishable Android 16 / Linux 6.6 bring-up tree:

- stock-GPT boot-header-v2 path is implemented
- dtbo/super/vbmeta/release tooling exists
- modem/RIL blob extraction is no longer intentionally skipping radio pieces
- KernelSU/Magisk/NetHunter hooks are wired at source level

It is not yet a proven production daily-driver because physical RMX3171 tests
are still required for display, touch, audio, charging, fingerprint, camera,
Mali userspace acceleration, and cellular/VoLTE.
