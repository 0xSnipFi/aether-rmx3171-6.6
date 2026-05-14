# RMX3171 Android 16 Partition Strategy

## Ground Truth

Narzo 30A / RMX3171 stock layout is not a native Android 16 GKI layout:

- boot header v2
- physical `boot`
- physical `dtbo`
- physical `super`
- physical `md1img`
- no physical `md1dsp` by-name entry on the captured RMX3171 dump
- no physical `vendor_boot`
- no physical `init_boot`
- no physical `vendor_dlkm`
- no physical `system_dlkm`
- no A/B slot suffix

Physical PGPT partition sizes matter. A bad PGPT/SGPT edit can hard-brick the
device or destroy NVRAM/NVDATA/PERSIST calibration. Production builds must not
depend on PGPT remapping.

## Production Path

Use stock physical partitions:

| Partition | Source | Size / handling |
|---|---|---|
| `boot` | physical GPT | stock boot-header-v2 kernel + ramdisk + DTB |
| `dtbo` | physical GPT | 8 MiB, built by `scripts/build/pack_dtbo.sh` |
| `super` | physical GPT | dynamic super, group size from `BoardConfig.mk` |
| `md1img` | physical GPT or vendor firmware mirror | modem firmware must be retained |
| `md1dsp.img` | vendor firmware / stock dump mirror | modem DSP firmware must be retained, but not mounted as a physical fstab partition on current RMX3171 dumps |

Inside custom `super.img`, add logical partitions:

| Logical partition | Purpose |
|---|---|
| `vendor_dlkm` | vendor/MTK modules |
| `system_dlkm` | GKI-ish/system modules |

This gives Android 16-style module separation without changing the physical
partition table.

## Do Not Make These Default

- physical `vendor_boot`
- physical `init_boot`
- physical `vendor_dlkm`
- physical `system_dlkm`

Those are PGPT-remap research targets only. Even if the partitions are added,
stock LK may ignore `vendor_boot` and `init_boot` because RMX3171 bootloader
was designed for boot-header-v2.

## Modem Rule

Never skip radio-critical blobs:

- `vendor/firmware/md1img.img`
- `vendor/firmware/md1dsp.img`
- `vendor/bin/hw/mtkfusionrild`
- `vendor/lib64/libmtk-ril.so`
- `vendor/lib64/librilfusion.so`
- `vendor/etc/apdb/APDB_MT6768_S01__W2044`
- `vendor/etc/apdb/APDB_MT6768_S01__W2044_ENUM`
- IMS/VoLTE services and OPLUS radio/appradio/ims blobs

Kernel ECCCI modules alone are not enough. Android 16 SIM/calls/LTE/VoLTE need
firmware, modem database, RIL, IMS, sepolicy, and physical SIM logs.
