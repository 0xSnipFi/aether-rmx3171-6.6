# Status snapshot - 2026-05-13 v10 ISP3 imgsensor

## Artifact

- `releases/AETHER_RMX3171_6.6_MT6768-20260513v10-imgsensor-isp3.zip`
- SHA-256: `856477d554aac26d03cf992df6541ffe757c813afd7c90e249e9c4fe1d594d88`
- `dtbo.img` SHA-256: `65a1a150fd5b4d52f89563f5bf6d250b6d985a26576a23e9300052f18c0a19e3`
- Linux base: 6.6.50 Samsung A055F + AETHER RMX3171 overlay
- Build result: successful with Ubuntu clang 14 engineering toolchain
- Packaged module count: 128 `.ko`

## What changed after v9

The MTK ISP3 camera chain now includes the RMX3171 imgsensor bridge module.
The build script applies the required gitignored `device-modules` source fixes
from tracked patch files and validates the expected markers before compiling.

Compile/package proof:

```text
modules/vendor_dlkm/mtk-smi.ko
modules/vendor_dlkm/mtk-smi-dbg.ko
modules/vendor_dlkm/iommu_debug.ko
modules/vendor_dlkm/irq-dbg.ko
modules/vendor_dlkm/mtk-cmdq-drv-ext.ko
modules/vendor_dlkm/cmdq_helper_inf.ko
modules/vendor_dlkm/camera_isp_3_m.ko
modules/vendor_dlkm/cam_qos_3.ko
modules/vendor_dlkm/imgsensor_isp3_m.ko
```

The imgsensor module contains RMX3171-family sensor init symbols:

```text
OV13B10MAIN_MIPI_RAW_SensorInit
S5K4H7FRONT_MIPI_RAW_SensorInit
W2GC02M1DEPSJ_MIPI_RAW_SensorInit
W2GC02M1MICROCXT_MIPI_RAW_SensorInit
```

## Camera reality

This is a real source/build improvement, not a final camera-working claim.
The kernel now packages ISP3 provider modules and a sensor bridge for likely
RMX3171 sensors. Physical validation is still required for:

- camera power rails and regulators
- MCLK/SENINF lane mapping
- sensor I2C addresses
- camera HAL blob compatibility
- preview/capture through Android 16 userspace

One compromise remains: `w2gc02m1microcxt` OTP is disabled in the experimental
module build to avoid pulling the full Wintech EEPROM/cam_cal stack. That makes
the 2MP calibration path incomplete until cam_cal is ported.

## GPU reality

Panfrost is enabled and packaged for Mali-G52 Bifrost:

```text
CONFIG_DRM_PANFROST=m
modules/system_dlkm/gpu-sched.ko
modules/system_dlkm/panfrost.ko
```

This is kernel-side render-node support. Full Android gaming/UI acceleration
still needs a compatible Mesa/Panfrost userspace path or a proprietary Bifrost
DDK port. Do not advertise Vulkan 1.3; Mali-G52 is realistically Vulkan 1.1
class.

## Cellular reality

ECCCI/CCCI/DPMAIF/CLDMA modules build and package:

```text
ccci_util_lib.ko
ccmni.ko
ccci_auxadc.ko
ccci_fsm_scp.ko
ccci_ccif.ko
ccci_dpmaif.ko
ccci_cldma.ko
ccci_md_all.ko
cpif.ko
rps_perf.ko
```

SIM/calls/data/VoLTE are not proven until modem firmware, RIL, IMS and physical
device logs confirm `/dev/ccci*`, `ccmni*`, SIM registration and IMS attach.

## Production blocker

The artifact was built with Ubuntu clang 14. Final production release should be
rebuilt with Android clang-r510928/clang 18+ and `AETHER_PRODUCTION_BUILD=1`.

## Honest claim

v10 is source-publishable as an Android 16 Linux 6.6 RMX3171 test candidate
with compile-proven camera ISP3/imgsensor, Panfrost G52, ECCCI modem modules,
KernelSU and NetHunter-friendly config. It is not yet hardware-proven as a full
daily driver because no physical RMX3171 boot log is present.
