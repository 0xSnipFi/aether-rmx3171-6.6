# Status snapshot - 2026-05-13 v11 camera autoload

## Artifact

- `releases/AETHER_RMX3171_6.6_MT6768-20260513v11-camera-autoload.zip`
- SHA-256: `c60d734778daff1fe54c1a2ed60a3555d910b7a17f616277c49123cf22362a5c`
- `dtbo.img` SHA-256: `65a1a150fd5b4d52f89563f5bf6d250b6d985a26576a23e9300052f18c0a19e3`
- Linux base: 6.6.50 Samsung A055F + AETHER RMX3171 overlay
- Build result: successful with Ubuntu clang 14 engineering toolchain
- Packaged module count: 128 `.ko`

## What changed after v10

The compile-proven ISP3 camera chain is now also listed in
`vendor_dlkm.modules.load`, so the v11 package is ready for physical camera
probe testing instead of only manual module insertion.

Auto-load manifest tail:

```text
mtk-smi.ko
mtk-smi-dbg.ko
iommu_debug.ko
irq-dbg.ko
mtk-cmdq-drv-ext.ko
cmdq_helper_inf.ko
camera_isp_3_m.ko
cam_qos_3.ko
imgsensor_isp3_m.ko
```

## Compile/package proof

```text
modules/vendor_dlkm/imgsensor_isp3_m.ko
modules/vendor_dlkm/camera_isp_3_m.ko
modules/vendor_dlkm/cam_qos_3.ko
modules/vendor_dlkm/ccci_md_all.ko
modules/vendor_dlkm/ccci_dpmaif.ko
modules/system_dlkm/panfrost.ko
```

`out/aether-external-modules.txt` contains 19 external MTK modules, and
`out/aether-built-modules.txt` contains 128 packaged module names.

## What is actually improved

- Camera kernel side advanced from provider-only to provider + RMX3171-family
  imgsensor bridge.
- Likely RMX3171 sensor functions are present:
  `OV13B10MAIN`, `S5K4H7FRONT`, `W2GC02M1DEPSJ`, `W2GC02M1MICROCXT`.
- Camera modules are now staged in the load manifest for real probe logs.
- Panfrost is still the kernel-side Mali-G52 path.
- ECCCI/CCCI/DPMAIF/CLDMA modem modules remain packaged for cellular tests.

## Still not proven

No physical RMX3171 `dmesg`/`logcat` was found in the repo. Therefore v11 is
not a certified daily-driver build yet. These require device logs:

- display/backlight
- touch
- audio speaker/earpiece/mic routing
- battery percentage and charging safety
- fingerprint enrollment/unlock
- WiFi/BT/FM firmware bring-up
- camera preview/capture through Android 16 camera HAL
- Panfrost render node plus Android userspace graphics compatibility
- SIM registration, calls, LTE data and VoLTE/IMS

## Production blocker

This artifact was built with Ubuntu clang 14. Final public production release
should be rebuilt with Android clang-r510928/clang 18+ and
`AETHER_PRODUCTION_BUILD=1`.

## Honest claim

v11 is the best current source-publishable Android 16 Linux 6.6 RMX3171 test
candidate. It is much closer to real daily-driver bring-up than v9/v10, but
daily-driver wording still waits on physical RMX3171 logs.
