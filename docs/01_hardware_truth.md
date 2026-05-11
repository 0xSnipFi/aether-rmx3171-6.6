# RMX3171 hardware truth (canonical evidence)

Source: `realme_rmx3171_dump-RMX3171_11.A.13_0130_202103090105/bootdts/01_dtbdump_MT6768.dts`
(stock A11 boot image DTB extracted), plus `device-info/RMX3171/getprop.txt`
(UTF-16LE decoded) and `narzo30A-stock/vendor_extracted/`.

This file is the single source-of-truth for every hardware decision in
`mt6768-rmx3171.dts` and `aether_rmx3171_defconfig`. No hardware value enters
production without a line here pointing at evidence.

## 1 SoC + board

| Field | Value | Evidence |
|---|---|---|
| Kernel platform | mt6768 | getprop `ro.board.platform`, stock DTB compatible `mediatek,MT6768` |
| Userspace alias | MT6769 | getprop `ro.mediatek.platform` |
| Board family | oppo6769 / RM6769 | getprop `ro.product.board` |
| CPU cores | 8 (4 LITTLE A55 + 4 BIG A75 logical, actually all A55 for G80/G85) | stock DTB `/cpus/cpu@000..@103` |
| Cluster split | cluster0 cpu@000-003 / cluster1 cpu@100-103 | DTB cpu-map |
| GIC | gic-v3, interrupt-parent=0x01 | stock DTB `/interrupt-controller` |

## 2 Connectivity

| Chip | Identity | Source |
|---|---|---|
| WiFi+BT combo | CONSYS MT6768 (chipid 0x6768) | getprop `persist.vendor.connsys.chipid`, stock ProjectConfig `MTK_WLAN_CHIP=CONSYS_MT6768` |
| FM radio | MT6631 | getprop `persist.vendor.connsys.fm_chipid` |
| GPS | MTK Combo GPS | stock ProjectConfig `MTK_COMBO_GPS=yes` |
| NFC | absent (RMX3171 has no NFC hardware) | stock ProjectConfig (no NFC chip line) |

## 3 Display

| Field | Value | Evidence |
|---|---|---|
| Active resolution | 720 x 1600 | getprop `persist.sys.oppo.displaymetrics`, stock LCM panel files |
| Panel candidates (stock build switch) | `ilt9881h_truly_hdp_dsi_vdo`, `nt36525b_hlt_hdp_dsi_vdo`, `ilt9881h_txd_hdp_dsi_vdo`, `nt36525b_hlt_psc_ac_boe_hdp_dsi_vdo`, `nt36525b_hlt_psc_ac_hdp_dsi_vdo`, `ilt9882n_txd_psc_ac_hdp_dsi_vdo` | stock ProjectConfig `CUSTOM_KERNEL_LCM` |
| Resolution-matching Samsung 6.6 dtsi | `cust_mt6768_touch_720x1600.dtsi` | Samsung A055F tree |

## 4 Touch

| Field | Value | Evidence |
|---|---|---|
| DTS node | `/touch` | stock DTB |
| Compatible | `mediatek,touch` (generic stub — real driver bound by `tpd_load_status.txt` userspace) | stock DTB |
| MTK driver | `drivers/input/touchscreen/mediatek/` shipped per-panel sub-driver (Focaltech, Goodix, Synaptics — needs identification from stock vendor blobs) | needs `vendor/lib*/hw/sensors.*.so` strings sweep |

## 5 Fingerprint

| Field | Value | Evidence |
|---|---|---|
| Active chip | **Goodix** (primary), Egis + FPC drivers also present as build options | stock DTB `/fingerprint compatible="mediatek,goodix-fp"` |
| Goodix node | `/fingerprint` | stock DTB phandle 0xb1 |
| Egis node | `/egis_fp` compatible=`mediatek,finger-fp` | stock DTB phandle 0xb2 |
| FPC node | `/fpc_interrupt` compatible=`fpc,fpc_irq` | stock DTB phandle 0xb3 |
| HAL chip identification | required from `vendor_extracted/vendor/lib(64)/hw/fingerprint.*.so` strings | TODO confirm |

## 6 Camera (sensor candidates)

From stock ProjectConfig `CUSTOM_KERNEL_IMGSENSOR`, the build supports the
union of Pascala/Pascali/Monet/MonetX/MonetD region variants. RMX3171 active
region uses a **subset** — only device boot logs reveal exact tuple.

Candidate main sensors:
- s5kgm1sp (Samsung 48MP)
- ov12a10 (OmniVision 12MP)
- ov13b10 (OmniVision 13MP)

Candidate front sensors:
- s5k4h7 (Samsung 8MP)
- gc5035 (GalaxyCore 5MP)
- ov16a1q (OmniVision 16MP)
- hi556 (Hynix 5MP)

Candidate aux (macro/depth/wide):
- ov02b10, ov02a1b, ov8856, gc2375h, gc2385, gc02m1b

Without device boot log, all are stubbed permissive in DTS; first boot prunes.

ISP framework: shared with Samsung 6.6 `cameraisp/`. Sensor framework: shared
with Samsung 6.6 `imgsensor/`.

## 7 Battery + Charger

| Field | Stock value | Evidence | Samsung 6.6 binding target |
|---|---|---|---|
| Battery capacity | 6000 mAh (NARZO 30A spec; community tree mentions 1000 mAh — bogus) | Realme RMX3171 product page | `mediatek,battery` `charge_full_design` |
| Algorithm | SwitchCharging | stock DTB `/charger/algorithm_name` | matches Samsung MTK charger driver |
| AC charger current | 2.05 A (0x1f47d0 = 2050000 µA) | stock DTB `/charger/ac_charger_current` | `mediatek,charger` `ac-charger-current` |
| AC input current | 3.2 A (0x30d400 = 3200000 µA) | stock DTB `/charger/ac_charger_input_current` | `ac-charger-input-current` |
| Battery CV | 4.35 V (0x426030 = 4350000 µV) | stock DTB `/charger/battery_cv` | `battery-cv` |
| Charging-host charger current | 1.5 A (0x16e360) | stock DTB | `charging-host-charger-current` |
| JEITA t0 cv | 4.045 V (0x3da540) | stock DTB `/charger/jeita_temp_below_t0_cv` | jeita override |
| JEITA t1-t2 cv | 4.24 V (0x40b280) | stock DTB | jeita override |
| JEITA t2-t3 cv | 4.34 V (0x423920) | stock DTB | jeita override |
| Type-C support | yes | stock DTB `enable_type_c` | `mediatek,tcpc` family |
| PD dual | disabled | stock DTB `disable_pd_dual` | charger DTS |
| PE40 high temp enter | 39°C (0x27) | stock DTB | PE40 fast-charge tuning |
| PE40 high temp leave | 46°C (0x2e) | stock DTB | PE40 |
| PE40 low temp enter | 16°C (0x10) | stock DTB | PE40 |
| Battery model fuelgauge profile | 100-point t0..t4 SOC curves present, byte-equal value capture in dts | stock DTB `/battery/battery0_profile_t0..t4` | `mediatek,bat_gm30` `battery0-profile-t0..t4` |
| Charger PMIC | MT6370 (charger + flashlight + BLED) | stock ProjectConfig `MTK_CHARGER_INTERFACE=mt6370_pmu_charger`, defconfig `CONFIG_MFD_MT6370_PMU=y` |
| Main PMIC | MT6358 | defconfig `CONFIG_MTK_PMIC_CHIP_MT6358=y` |
| Sub PMIC | MT6315 (CPU buck) | stock DTS reference |
| TCPC | RT1711H | defconfig `CONFIG_TCPC_RT1711H=y` |

## 8 Audio

| Field | Value | Evidence |
|---|---|---|
| Soundcard name | `mt6768mt6358` | AETHER 4.14 defconfig + RMX3171 audio_policy XML |
| Codec | MT6358 (integrated in main PMIC) | as above |
| Smart PA | sia81xx (Si AudioPlus 81xx series) | stock kernel source `sound/soc/mediatek/sia81xx/` |
| Audio jack | 3.5 mm with detect IRQ via ACCDET | stock DTB `/accdet` |
| MIC + speaker | digital MIC array + mono speaker | stock vendor audio_policy.xml |

## 9 Sensors

From AETHER 4.14 defconfig + stock DTB `__symbols__`:

| Sensor | Hub config |
|---|---|
| Accelerometer | `MTK_ACCELHUB`, custom kernel accelerometer |
| Magnetometer | `MTK_MAGHUB`, uncali variant `MTK_UNCALI_MAGHUB` |
| Gyroscope | `MTK_GYROHUB` |
| ALS + Proximity | `MTK_ALSPSHUB` |
| Step counter | `MTK_STEPSIGNHUB` |
| Pickup/Glance | `MTK_PICKUPHUB`, `MTK_GLGHUB` |
| Activity recognition | `OPLUS_FEATURE_ACTIVITY_RECOGNITION` |
| TP gesture (off-screen) | `OPLUS_FEATURE_TP_GESTURE` |
| Free fall | `OPLUS_FEATURE_FREE_FALL` |
| Camera protect (sensor) | `OPLUS_FEATURE_CAMERA_PROTECT` |
| Sensor hub framework | MTK SCP (Tinysys SCP) | stock ProjectConfig + defconfig `CONFIG_MTK_TINYSYS_SCP_SUPPORT=y` |

## 10 Storage + partitions

| Field | Value | Evidence |
|---|---|---|
| Flash type | eMMC 5.1 (no UFS on RMX3171) | stock fstab `mt6768.emmc` |
| Dynamic partitions | yes (super.img) | getprop `ro.boot.dynamic_partitions=true` |
| Logical partitions | system, vendor, product, system_ext, odm (super) | stock super_extracted |
| ICE (inline crypto) | not enabled in stock A11 (added at A13+) | needs new for A16 |

## 11 USB / Type-C

| Field | Value | Evidence |
|---|---|---|
| Controller | MUSB QMU (MTK SoC USB) | defconfig `CONFIG_USB_MTK_HDRC=y`, `CONFIG_MTK_MUSB_QMU_SUPPORT=y` |
| Type-C controller | RT1711H | defconfig `CONFIG_TCPC_RT1711H=y` |
| Type-C mode | USB 2.0 only (no U3 superspeed on RMX3171) | stock DTS no U3 lanes |
| OTG | yes | defconfig `CONFIG_USB_MTK_OTG=y` |
| PD | disabled (BC1.2 + PE) | stock charger `disable_pd_dual` |

## 12 Firmware blobs (path layout in stock vendor)

| Component | Path |
|---|---|
| WiFi firmware | `vendor/firmware/WIFI_RAM_CODE_MT6631` |
| BT firmware | `vendor/firmware/BT_RAM_CODE_MT6631` |
| SCP firmware | `vendor/firmware/scp.img` |
| MD modem firmware | `vendor/firmware/md1*.img`, `md1*_dsp.bin` |
| Mali GPU blobs | `vendor/lib(64)/egl/libGLES_mali.so` (proprietary user-space DDK) |
| Camera HAL blobs | `vendor/lib(64)/hw/camera.mt6768.so` (proprietary) |
| FP HAL blobs | `vendor/lib(64)/hw/fingerprint.goodix.so` (active) |

## 13 What's missing from this evidence (gaps)

These cannot be filled without device:

- Exact LCM panel ID in this RMX3171 production unit (one of six candidates).
- Exact camera sensor tuple in this region.
- Exact touch controller chip (Focaltech vs Goodix vs Synaptics).
- Exact fingerprint HAL service name (`vendor/etc/init/fingerprint*.rc`).
- GPU OPP voltage table for this silicon bin.
- Real-time charger curve under thermal load.

These remain as `TODO_DEVICE_BOOT` markers in the new DTS.
