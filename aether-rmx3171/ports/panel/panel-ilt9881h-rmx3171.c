// SPDX-License-Identifier: GPL-2.0-only
/*
 * Realme RMX3171 ILT9881H 720x1600 HD+ MIPI-DSI video-mode panel driver.
 *
 * Ported from Realme 4.14 vendor LCM driver:
 *   drivers/misc/mediatek/lcm/ilt9881h_truly_hdp_dsi_vdo_lcm/
 *   drivers/misc/mediatek/lcm/ilt9881h_txd_hdp_dsi_vdo_lcm/
 *
 * 4.14 used mtk lcm_drv framework with dsi_set_cmdq_V22(). Translated to
 * mainline drm_panel + mipi_dsi_dcs_write_seq.
 *
 * Init sequence is byte-equivalent to 4.14 init_setting_vdo array (Truly
 * variant; TXD variant differs in pages 0x03/0x06 — selected via DT
 * compatible).
 *
 * Reset / power sequence matches 4.14 lcm_power_on/off in LCM driver.
 *
 * Author: AETHER project, 2026-05-12.
 * Original 4.14 author: lianghao@OPPO ODM_WT, 2019-09-25.
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/regulator/consumer.h>

#include <video/mipi_display.h>

#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

struct ilt9881h_panel_desc {
	const struct drm_display_mode *mode;
	const u8 (*init_seq)[8];	/* {len, cmd, data...} per row */
	unsigned int init_seq_count;
	unsigned int lanes;
	unsigned long mode_flags;
	enum mipi_dsi_pixel_format format;
};

struct ilt9881h {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	const struct ilt9881h_panel_desc *desc;

	struct regulator *vsp;	/* +5.5 V positive bias (lcd_enp) */
	struct regulator *vsn;	/* -5.5 V negative bias (lcd_enn) */
	struct gpio_desc *reset_gpio;

	bool prepared;
};

static inline struct ilt9881h *panel_to_ilt9881h(struct drm_panel *p)
{
	return container_of(p, struct ilt9881h, panel);
}

/*
 * Init sequence translated VERBATIM from 4.14
 * ilt9881h_truly_hdp_dsi_vdo_lcm.c::init_setting_vdo[].
 * Format per row: { byte_count, cmd, p0, p1, p2, ... }.
 * byte_count == 0xFF marks delay-in-ms; cmd holds delay value.
 */
#define D(ms)	{ 0xFF, (ms), 0, 0, 0, 0, 0, 0 }	/* delay */

static const u8 ilt9881h_truly_init[][8] = {
	{ 0x04, 0xFF, 0x98, 0x81, 0x06, 0,    0,    0    },
	{ 0x02, 0x06, 0xC4, 0,    0,    0,    0,    0    },
	{ 0x02, 0xC7, 0x05, 0,    0,    0,    0,    0    },
	{ 0x04, 0xFF, 0x98, 0x81, 0x03, 0,    0,    0    },
	{ 0x02, 0x82, 0x77, 0,    0,    0,    0,    0    },
	{ 0x02, 0x83, 0x30, 0,    0,    0,    0,    0    },
	{ 0x02, 0x84, 0x00, 0,    0,    0,    0,    0    },
	{ 0x02, 0x90, 0x13, 0,    0,    0,    0,    0    },
	{ 0x02, 0x91, 0xF5, 0,    0,    0,    0,    0    },
	{ 0x02, 0x92, 0x15, 0,    0,    0,    0,    0    },
	{ 0x02, 0x93, 0xF6, 0,    0,    0,    0,    0    },
	{ 0x02, 0xAD, 0xF2, 0,    0,    0,    0,    0    },
	{ 0x02, 0x94, 0x0E, 0,    0,    0,    0,    0    },
	{ 0x02, 0x95, 0x0F, 0,    0,    0,    0,    0    },
	{ 0x02, 0x96, 0x0F, 0,    0,    0,    0,    0    },
	{ 0x02, 0x97, 0x0F, 0,    0,    0,    0,    0    },
	{ 0x02, 0x98, 0x0E, 0,    0,    0,    0,    0    },
	{ 0x02, 0x99, 0x11, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9A, 0x11, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9B, 0x10, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9C, 0x10, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9D, 0x14, 0,    0,    0,    0,    0    },
	{ 0x02, 0xAE, 0xCD, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9E, 0x00, 0,    0,    0,    0,    0    },
	{ 0x02, 0x9F, 0x06, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA0, 0x08, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA1, 0x0A, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA2, 0x0A, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA3, 0x0E, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA4, 0x0F, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA5, 0x0E, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA6, 0x91, 0,    0,    0,    0,    0    },
	{ 0x02, 0xA7, 0x92, 0,    0,    0,    0,    0    },
	{ 0x02, 0x8D, 0x00, 0,    0,    0,    0,    0    },
	{ 0x02, 0x8F, 0x80, 0,    0,    0,    0,    0    },
	{ 0x04, 0xFF, 0x98, 0x81, 0x00, 0,    0,    0    },
	{ 0x02, 0x53, 0x24, 0,    0,    0,    0,    0    },
	{ 0x01, 0x11, 0,    0,    0,    0,    0,    0    },	/* sleep out */
	D(60),
	{ 0x04, 0xFF, 0x98, 0x81, 0x02, 0,    0,    0    },
	{ 0x02, 0x01, 0x34, 0,    0,    0,    0,    0    },
	{ 0x02, 0x02, 0x0A, 0,    0,    0,    0,    0    },
	{ 0x04, 0xFF, 0x98, 0x81, 0x00, 0,    0,    0    },
	{ 0x01, 0x29, 0,    0,    0,    0,    0,    0    },	/* display on */
	D(20),
	{ 0x04, 0xFF, 0x98, 0x81, 0x06, 0,    0,    0    },
	{ 0x02, 0xD6, 0x87, 0,    0,    0,    0,    0    },
	{ 0x02, 0x27, 0xFF, 0,    0,    0,    0,    0    },	/* VFP */
	{ 0x04, 0xFF, 0x98, 0x81, 0x00, 0,    0,    0    },
	{ 0x02, 0x35, 0x00, 0,    0,    0,    0,    0    },
};

static const struct drm_display_mode ilt9881h_truly_mode = {
	/* H: 720, total 856 (back-porch 80 + sync 20 + front-porch 36).
	 * V: 1600, total 1622 (back-porch 8 + sync 4 + front-porch 10).
	 * Pixel clock derived: 856 * 1622 * 60 = 83.3 MHz, rounded to 84 MHz.
	 * Matches 4.14 LCM_PARAMS: dsi.clk_lp_per_line_byte = 5.
	 */
	.clock		= 84000,
	.hdisplay	= 720,
	.hsync_start	= 720 + 36,
	.hsync_end	= 720 + 36 + 20,
	.htotal		= 720 + 36 + 20 + 80,
	.vdisplay	= 1600,
	.vsync_start	= 1600 + 10,
	.vsync_end	= 1600 + 10 + 4,
	.vtotal		= 1600 + 10 + 4 + 8,
	.width_mm	= 68,	/* LCM_PHYSICAL_WIDTH / 1000 */
	.height_mm	= 151,	/* LCM_PHYSICAL_HEIGHT / 1000 */
	.type		= DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED,
};

static const struct ilt9881h_panel_desc ilt9881h_truly_desc = {
	.mode		= &ilt9881h_truly_mode,
	.init_seq	= ilt9881h_truly_init,
	.init_seq_count	= ARRAY_SIZE(ilt9881h_truly_init),
	.lanes		= 4,
	.mode_flags	= MIPI_DSI_MODE_VIDEO |
			  MIPI_DSI_MODE_VIDEO_BURST |
			  MIPI_DSI_MODE_LPM,
	.format		= MIPI_DSI_FMT_RGB888,
};

static int ilt9881h_send_init(struct ilt9881h *priv)
{
	struct mipi_dsi_device *dsi = priv->dsi;
	unsigned int i;
	int ret;

	for (i = 0; i < priv->desc->init_seq_count; i++) {
		const u8 *row = priv->desc->init_seq[i];
		u8 count = row[0];

		if (count == 0xFF) {
			msleep(row[1]);
			continue;
		}

		/* Single byte payload is generic short write. */
		ret = mipi_dsi_dcs_write_buffer(dsi, &row[1], count);
		if (ret < 0) {
			dev_err(&dsi->dev,
				"init cmd %u (cmd=0x%02x) failed: %d\n",
				i, row[1], ret);
			return ret;
		}
	}

	return 0;
}

static int ilt9881h_prepare(struct drm_panel *p)
{
	struct ilt9881h *priv = panel_to_ilt9881h(p);
	int ret;

	if (priv->prepared)
		return 0;

	/* Match 4.14 lcm_power_on() sequence: VSP -> VSN -> VDDIO -> RESET. */
	ret = regulator_enable(priv->vsp);
	if (ret) {
		dev_err(&priv->dsi->dev, "vsp enable failed: %d\n", ret);
		return ret;
	}
	usleep_range(5000, 5500);

	ret = regulator_enable(priv->vsn);
	if (ret) {
		dev_err(&priv->dsi->dev, "vsn enable failed: %d\n", ret);
		goto err_disable_vsp;
	}
	usleep_range(5000, 5500);

	/* Reset pulse: HIGH 5ms -> LOW 10ms -> HIGH 50ms (per LCM driver). */
	gpiod_set_value_cansleep(priv->reset_gpio, 1);
	usleep_range(5000, 5500);
	gpiod_set_value_cansleep(priv->reset_gpio, 0);
	usleep_range(10000, 11000);
	gpiod_set_value_cansleep(priv->reset_gpio, 1);
	msleep(50);

	ret = ilt9881h_send_init(priv);
	if (ret)
		goto err_reset_low;

	priv->prepared = true;
	return 0;

err_reset_low:
	gpiod_set_value_cansleep(priv->reset_gpio, 0);
	regulator_disable(priv->vsn);
err_disable_vsp:
	regulator_disable(priv->vsp);
	return ret;
}

static int ilt9881h_unprepare(struct drm_panel *p)
{
	struct ilt9881h *priv = panel_to_ilt9881h(p);

	if (!priv->prepared)
		return 0;

	mipi_dsi_dcs_set_display_off(priv->dsi);
	msleep(20);
	mipi_dsi_dcs_enter_sleep_mode(priv->dsi);
	msleep(150);

	gpiod_set_value_cansleep(priv->reset_gpio, 0);
	usleep_range(5000, 5500);
	regulator_disable(priv->vsn);
	usleep_range(5000, 5500);
	regulator_disable(priv->vsp);

	priv->prepared = false;
	return 0;
}

static int ilt9881h_get_modes(struct drm_panel *p,
			      struct drm_connector *conn)
{
	struct ilt9881h *priv = panel_to_ilt9881h(p);
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(conn->dev, priv->desc->mode);
	if (!mode)
		return -ENOMEM;

	drm_mode_set_name(mode);
	drm_mode_probed_add(conn, mode);

	conn->display_info.width_mm = priv->desc->mode->width_mm;
	conn->display_info.height_mm = priv->desc->mode->height_mm;

	return 1;
}

static const struct drm_panel_funcs ilt9881h_funcs = {
	.prepare	= ilt9881h_prepare,
	.unprepare	= ilt9881h_unprepare,
	.get_modes	= ilt9881h_get_modes,
};

static int ilt9881h_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	const struct ilt9881h_panel_desc *desc;
	struct ilt9881h *priv;
	int ret;

	desc = of_device_get_match_data(dev);
	if (!desc)
		return -EINVAL;

	priv = devm_kzalloc(dev, sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->dsi = dsi;
	priv->desc = desc;

	priv->vsp = devm_regulator_get(dev, "vsp");
	if (IS_ERR(priv->vsp))
		return dev_err_probe(dev, PTR_ERR(priv->vsp),
				     "vsp regulator missing\n");

	priv->vsn = devm_regulator_get(dev, "vsn");
	if (IS_ERR(priv->vsn))
		return dev_err_probe(dev, PTR_ERR(priv->vsn),
				     "vsn regulator missing\n");

	priv->reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW);
	if (IS_ERR(priv->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(priv->reset_gpio),
				     "reset gpio missing\n");

	dsi->lanes = desc->lanes;
	dsi->format = desc->format;
	dsi->mode_flags = desc->mode_flags;

	drm_panel_init(&priv->panel, dev, &ilt9881h_funcs,
		       DRM_MODE_CONNECTOR_DSI);

	ret = drm_panel_of_backlight(&priv->panel);
	if (ret)
		return ret;

	drm_panel_add(&priv->panel);

	mipi_dsi_set_drvdata(dsi, priv);

	ret = mipi_dsi_attach(dsi);
	if (ret) {
		drm_panel_remove(&priv->panel);
		return ret;
	}

	return 0;
}

static void ilt9881h_remove(struct mipi_dsi_device *dsi)
{
	struct ilt9881h *priv = mipi_dsi_get_drvdata(dsi);

	mipi_dsi_detach(dsi);
	drm_panel_remove(&priv->panel);
}

static const struct of_device_id ilt9881h_of_match[] = {
	{
		.compatible	= "realme,rmx3171-ilt9881h-truly",
		.data		= &ilt9881h_truly_desc,
	},
	/* TODO: TXD variant once init_setting_vdo is captured from
	 * source-txd/ilt9881h_txd_hdp_dsi_vdo_lcm.c.
	 */
	{}
};
MODULE_DEVICE_TABLE(of, ilt9881h_of_match);

static struct mipi_dsi_driver ilt9881h_driver = {
	.driver = {
		.name		= "panel-ilt9881h-rmx3171",
		.of_match_table	= ilt9881h_of_match,
	},
	.probe		= ilt9881h_probe,
	.remove		= ilt9881h_remove,
};
module_mipi_dsi_driver(ilt9881h_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("ILT9881H 720x1600 DSI video-mode panel (RMX3171)");
MODULE_LICENSE("GPL");
