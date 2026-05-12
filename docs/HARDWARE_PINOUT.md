# Realme Narzo 30A (RMX3171) hardware pinout

SoC: MediaTek MT6768 (Helio G85). 12 nm, Cortex-A75 ×2 + A55 ×6, Mali-G52 MC1.

## Stock device specs (verified)

| Item | Value | Source |
|---|---|---|
| SoC | MediaTek MT6768 (Helio G85) | Realme spec sheet |
| CPU | 2× Cortex-A75 @ 2.0 GHz + 6× Cortex-A55 @ 1.8 GHz | |
| GPU | Mali-G52 MC1 @ 950 MHz | |
| RAM | 4 GB LPDDR4X | 3 GB SKU also exists |
| Storage | 64 GB eMMC 5.1 + microSD | |
| Display | 6.5" HD+ 720×1600 IPS LCD, 60 Hz | ILT9881H (Truly/TXD variant) |
| Touch | Novatek NT36525B | 10-finger capacitive, I²C @ 0x62 |
| Battery | 6000 mAh Li-Po | |
| Charging | **18W Quick Charge** (9V/2A via MTK PE+) | NOT 30W |
| Camera rear | 13 MP main (ov13b10) + 2 MP macro (gc2375h) + 2 MP depth (ov02a1b) | |
| Camera front | 8 MP (s5k4h7) | |
| Audio | MT6358 codec + sia81xx smart PA | speaker |
| WiFi | 802.11 b/g/n single-band (MT6631 combo) | 2.4 GHz only |
| Bluetooth | 5.0 (MT6631 combo) | |
| GPS | A-GPS + GLONASS + BDS (MT6631 combo) | |
| FM | yes (MT6631 combo) | RDS support |
| Fingerprint | rear-mounted, Goodix GF3208 (capacitive) | |
| Sensors | accel (bmi160), gyro (bmi160), mag (akm09918), prox, ambient light | |
| USB | Type-C 2.0, OTG support | charge + data |
| Modem | MTK integrated 4G LTE | Cat 4 |
| NFC | none | |
| IR blaster | none | |
| 3.5mm jack | yes | |

## GPIO pinout (from 4.14 DTS evidence)

Critical pins used by AETHER drivers:

| Function | GPIO | Notes |
|---|---:|---|
| LCD reset | 45 | active-low; ilt9881h panel reset |
| LCD VSP enable | (PMIC) | mt6358 dsv_pos |
| LCD VSN enable | (PMIC) | mt6358 dsv_neg |
| Touch reset | 23 | active-high; NT36525B reset |
| Touch IRQ | 0 | falling-edge |
| sia81xx PA enable | 132 | active-high |
| Fingerprint reset | 156 | active-low |
| Fingerprint IRQ | 1 | rising-edge |
| Vibrator | (PMIC) | mt6358 dedicated pin |
| Flashlight | (PMIC) | mt6370 LED flash |
| Volume up | 5 | KEY_VOLUMEUP |
| Volume down | 6 | KEY_VOLUMEDOWN |
| Power button | (PMIC) | mt6358 pwrkey |
| USB-C VBUS detect | 16 | active-high |

## I²C bus map

| Bus | Speed | Devices |
|---|---|---|
| `i2c0` | 100 kHz | MT6358 PMIC sub-channels |
| `i2c1` | 400 kHz | NT36525B touchscreen @ 0x62 |
| `i2c2` | 400 kHz | accel/gyro/mag |
| `i2c3` | 400 kHz | charger MT6370 @ 0x34 |
| `i2c4` | 400 kHz | sia81xx PA @ 0x1c |
| `i2c5` | 100 kHz | camera sensors (rear/front) |
| `i2c6` | 400 kHz | NFC (not populated on RMX3171) |

## SPI bus map

| Bus | Speed | Devices |
|---|---|---|
| `spi0` | 1 MHz | unused |
| `spi1` | 8 MHz | Goodix GF3208 fingerprint |

## Pinctrl groups

95 pin groups extracted from stock A11 boot DTB.
See `aether-rmx3171/dts/cust_mt6768_rmx3171_pinctrl.dtsi`.

Each group covers a function set: touch, panel, camera, audio, USB, etc.

## Battery profile

4 batteries × 5 temperatures × 100 SOC points.
See `aether-rmx3171/dts/rmx3171_bat_profile.dtsi` — byte-equivalent with
stock A11 factory image.

Used by `aether-simple-gauge.ko` for voltage→SOC lookup.

## SoC memory map (highlights)

| Region | Base | Size | Purpose |
|---|---|---|---|
| MCUSYS | 0x0c000000 | 64 KB | CPU subsystem registers |
| MCUCFG | 0x0c530000 | 4 KB | CPU config |
| MMSYS | 0x14000000 | 16 KB | display/camera bus |
| MFGSYS | 0x13000000 | 4 KB | Mali GPU control |
| IMGSYS | 0x15000000 | 8 KB | ISP3 cameraisp |
| DISP0 | 0x14004000 | various | DSI / OVL / RDMA / WDMA |
| MSDC0 | 0x11230000 | 4 KB | eMMC controller |
| MSDC1 | 0x11240000 | 4 KB | SD card controller |
| UART0 | 0x11002000 | 4 KB | early console |
| I2C0–6 | 0x11008000 + n × 4 KB | | I²C controllers |
| SPI0–5 | 0x1100a000 + n × 4 KB | | SPI controllers |
| USB | 0x11200000 | various | xhci-mtk + mtu3 |
| GIC | 0x0c000000 | various | interrupt controller |

## Power domains (SCP-managed)

- MFG (Mali GPU)
- ISP (camera ISP3)
- DIS0 / DIS1 (display)
- VEN (video encode)
- VDE (video decode)
- AUDIO
- CONN (connsys combo)
- MFG_2D / MFG_ASYNC
- VCORE

Controlled via `mt6358-regulator` + MTK SCPSYS framework.

## Clock tree highlights

| Clock | Rate | Purpose |
|---|---|---|
| `clk26m` | 26 MHz | reference oscillator |
| `clk13m` | 13 MHz | half-divider |
| MAINPLL | 1066 MHz | CPU/bus base |
| MMPLL | 416 MHz | display/multimedia |
| MFGPLL | 850 MHz | Mali GPU |
| MSDCPLL | 384 MHz | eMMC PHY |
| TCONPLL | 312 MHz | display timing |
| UNIVPLL | 1248 MHz | USB/peripheral |

Full clock list: `aether-rmx3171/ports/TODO/clk-mt6768/mt6768-clk.h`.

## Bootloader

Realme LK (Little Kernel) custom build. Configures DRAM, PMIC, eMMC,
display panel pre-init, then loads boot.img / vendor_boot.img.

Unlocked via `fastboot oem unlock` (requires Realme Bootloader Unlock
Tool + 14-day waiting period on stock firmware).

## Modem firmware

`md1img.img` + `md1dsp.img` in stock vendor partition. Required for 4G
cellular. Skipped in current AETHER 6.6 (no ECCCI port yet).

## Mali GPU firmware

Built-in to Mali-G52 silicon — no separate firmware blob needed for
kernel driver. Userspace `libGLES_mali.so` must match kernel driver
version (Bifrost r25p0 in our planned port).
