# panel-ilt9881h — RMX3171 LCD (Truly / TXD variants)

## What this is

4.14 MTK `lcm` panel driver. Two vendor variants of same ILT9881H controller:
- Truly HDP DSI VDO LCM (`source-truly/`)
- TXD HDP DSI VDO LCM (`source-txd/`)

Both are HD+ (720×1600) MIPI-DSI video-mode panels.

## 4.14 vs 6.6 paradigm

| 4.14 `mtkfb` LCM | 6.6 DRM panel |
|---|---|
| `lcm_init_power`, `lcm_resume`, `lcm_suspend` ops | `drm_panel_funcs` (prepare/enable/disable/unprepare) |
| `lcm_util.dsi_set_cmdq()` raw bytes | `mipi_dsi_dcs_write[_seq]` |
| `MTKFB_GET_POWER_MODE` ioctl | `drm_panel_get_modes()` |
| 4.14 builds into `drivers/misc/mediatek/lcm/` | 6.6 builds into `drivers/gpu/drm/panel/` |

## Port plan

1. Grep `source-truly/ilt9881h_truly_hdp_dsi_vdo_lcm.c` for `init_setting` /
   `dsi_init_cmds` arrays — these are the DCS init bytes. Capture them.
2. Capture timing block: `disp_lcm_timing` → maps to `display_timing` struct.
3. Capture reset GPIO sequence (usually `RST_HIGH 5ms; RST_LOW 5ms; RST_HIGH 50ms`).
4. Capture backlight (PWM or CABC).
5. Skeleton driver pattern: copy `drivers/gpu/drm/panel/panel-novatek-nt36523.c`
   (already in 6.6, similar HD MIPI panel).

## Skeleton

```c
// drivers/gpu/drm/panel/panel-ilt9881h.c
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>
#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

struct ilt9881h {
    struct drm_panel panel;
    struct mipi_dsi_device *dsi;
    struct gpio_desc *reset;
    struct regulator *vsp, *vsn;
};

static int ilt9881h_send_init(struct ilt9881h *p)
{
    struct mipi_dsi_device *dsi = p->dsi;

    /* PASTE init seq from 4.14 dsi_init_cmds */
    mipi_dsi_dcs_write_seq(dsi, 0xE0, 0x00);
    mipi_dsi_dcs_write_seq(dsi, 0xE1, 0x93);
    /* ... */
    mipi_dsi_dcs_write_seq(dsi, MIPI_DCS_EXIT_SLEEP_MODE);
    msleep(120);
    mipi_dsi_dcs_write_seq(dsi, MIPI_DCS_SET_DISPLAY_ON);
    return 0;
}

static const struct drm_display_mode ilt9881h_mode = {
    .clock = 84000,  /* kHz, derived from 4.14 PLL_CLOCK */
    .hdisplay = 720, .hsync_start = 720 + 80,
    .hsync_end = 720 + 80 + 20, .htotal = 720 + 80 + 20 + 80,
    .vdisplay = 1600, .vsync_start = 1600 + 10,
    .vsync_end = 1600 + 10 + 4, .vtotal = 1600 + 10 + 4 + 8,
    .width_mm = 67, .height_mm = 150,
};
```

## Files staged

| Path | Variant |
|---|---|
| `source-truly/ilt9881h_truly_hdp_dsi_vdo_lcm.c` | Truly |
| `source-txd/ilt9881h_txd_hdp_dsi_vdo_lcm.c` | TXD |

Read **both** before merging — pick the init that matches your physical panel,
or compile both and select via DT `compatible` ("realme,rmx3171-ilt9881h-truly"
vs "...-txd").

## DT binding

```dts
&dsi0 {
    panel@0 {
        compatible = "realme,rmx3171-ilt9881h-truly";
        reg = <0>;
        reset-gpios = <&pio 45 GPIO_ACTIVE_LOW>;
        vsp-supply = <&dsv_pos>;
        vsn-supply = <&dsv_neg>;
        backlight = <&pwm_bl>;
    };
};
```

## Acceptance

- Boot logo visible.
- `cat /sys/class/drm/card0-DSI-1/status` = `connected`.
- `kmsprint` shows correct mode.

## Status: P1, deferred (needs device test loop).
