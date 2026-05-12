# AETHER MT6768 driver ports to ACK 6.6

Drivers ported from Realme 4.14.336 (`kernel_realme_RMX2020-sixteen-qpr2`-style
source) to Android Common Kernel 6.6.129 API.

## What's ported

### pinctrl-mt6768.c (DONE, builds clean)

Source: 4.14 `drivers/pinctrl/mediatek/pinctrl-mt6768.c` + `pinctrl-mtk-mt6768.h`
Destination: 6.6 ACK `drivers/pinctrl/mediatek/`

API adaptations made:

| 4.14 API | 6.6 API |
|---|---|
| `mtk_pinconf_drive_set_direct_val` | `mtk_pinconf_drive_set_raw` |
| `mtk_pinconf_drive_get_direct_val` | `mtk_pinconf_drive_get_raw` |
| `.race_free_access = true` (mtk_pin_soc field) | dropped (no longer exists) |
| `mtk_paris_pinctrl_probe(pdev, &data)` | `mtk_paris_pinctrl_probe(pdev)` — data via `of_device_id .data` |
| `.pm = &mtk_eint_pm_ops_v2` | dropped (paris framework handles PM internally) |

Verified in vmlinux symbols: `mt6768_pinctrl_init` initcall present.

### aether_mtk_enable.config (DONE)

Config overlay enabling MT6768 base hardware support in ACK 6.6 defconfig.
Merge via `scripts/kconfig/merge_config.sh`.

Configs enabled:
- `ARCH_MEDIATEK=y` (platform gate)
- `PINCTRL_MTK_PARIS=y`
- `PINCTRL_MT6768=y` (this port)
- `MMC_MTK=y` (mainline mtk-sd; covers MT6768)
- `MFD_MT6397=y` (MFD framework; MT6358 PMIC handled here)
- `REGULATOR_MT6358=y` (PMIC regulator)
- `RTC_DRV_MT6397=y` (PMIC RTC)
- `MFD_MT6370=y` (charger MFD)
- `CHARGER_MT6370=y` (battery charger)
- `MTK_PMIC_WRAP=y` (PMIC wrapper bus)
- `MEDIATEK_MT6577_AUXADC=y` (battery voltage measurement)

## After applying this overlay

vmlinux MT6768 symbol count: **1 → 222**

Initcalls visible:
- `mt6768_pinctrl_init`
- `mt6358_regulator_driver_init`
- `mt6370_driver_init`
- `mt6370_chg_driver_init`
- `mt_msdc_driver_init` (eMMC)

## Still to port (priority order)

| Driver | Source | Priority |
|---|---|---|
| `clk-mt6768.c` (3365 lines + power-gate) | 4.14 `clk/mediatek/clk-mt6768*.c` | HIGH — clk subsystem |
| MT6768 display LCM | 4.14 `drivers/misc/mediatek/video/` | HIGH — boot UI |
| Touchscreen (Focaltech/Goodix probe) | 4.14 `drivers/input/touchscreen/mediatek/` | HIGH — input |
| Battery gm30 fuelgauge | 4.14 `drivers/power/supply/mtk_battery.c` | MED — fuelgauge driver |
| Sensor hub SCP | 4.14 `drivers/misc/mediatek/scp/` | MED — sensors |
| Audio mt6358 + sia81xx | 4.14 `sound/soc/mediatek/` | MED — audio |
| BT mt66xx | 4.14 `drivers/misc/mediatek/btif/` + `connectivity/bt/` | LOW |
| FM mt6631 | 4.14 `drivers/misc/mediatek/connectivity/fmradio/` | LOW |
| GPU Mali avalon | 4.14 `drivers/gpu/arm/midgard/` | HIGHEST EFFORT — port last |
| Camera ISP + imgsensor | 4.14 `drivers/misc/mediatek/cameraisp/` + `imgsensor/` | HIGHEST EFFORT |

## How to use

```bash
# 1. Stage source files into your ACK 6.6 tree
cp aether-rmx3171/ports/pinctrl/pinctrl-mt6768.c     \
   <your-ack-6.6>/drivers/pinctrl/mediatek/
cp aether-rmx3171/ports/pinctrl/pinctrl-mtk-mt6768.h \
   <your-ack-6.6>/drivers/pinctrl/mediatek/

# 2. Patch Kconfig (add PINCTRL_MT6768 entry after PINCTRL_MT6765)
# 3. Patch Makefile (add: obj-$(CONFIG_PINCTRL_MT6768) += pinctrl-mt6768.o)
# 4. Apply config overlay
bash scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    aether-rmx3171/ports/configs/aether_mtk_enable.config

# 5. Build
make ARCH=arm64 CC=clang LLVM=1 CROSS_COMPILE=aarch64-linux-gnu- \
    O=$OUT -j$(nproc) Image modules
```
