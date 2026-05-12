// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — minimal sia81xx ASoC codec driver.
 *
 * Replaces 3500-LoC 4.14 vendor driver with regmap-based codec exposing
 * a single power-on / mute / volume control path. Drops:
 *   - OWI single-wire interface bring-up (replaced by I2C-only flow)
 *   - tuning_if userspace shim
 *   - vendor timer_task / socket IPC
 *   - dynamic VDD scaling
 *
 * Auto-detects sia8101 (0x01), sia8108 (0x08), sia8109 (0x09) via CHIPID
 * register.
 *
 * Register map summary (verified against 4.14 sia810x_regs.[ch] files):
 *   0x00  CHIPID    (RO)   chip identifier
 *   0x01  SYSCTRL          bit0 = enable (1 = on)
 *   0x06  VOLUME           5-bit attenuation (0 = max, 31 = mute)
 *   0x10  STATUS    (RO)   protection / error flags
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regmap.h>
#include <linux/gpio/consumer.h>
#include <linux/delay.h>

#include <sound/pcm.h>
#include <sound/pcm_params.h>
#include <sound/soc.h>
#include <sound/soc-dai.h>
#include <sound/soc-dapm.h>
#include <sound/tlv.h>

#define SIA81XX_REG_CHIPID	0x00
#define SIA81XX_REG_SYSCTRL	0x01
#define SIA81XX_REG_VOLUME	0x06
#define SIA81XX_REG_STATUS	0x10
#define SIA81XX_REG_MAX		0x7F

#define SIA81XX_SYSCTRL_EN	BIT(0)

#define SIA8101_CHIPID		0x01
#define SIA8108_CHIPID		0x08
#define SIA8109_CHIPID		0x09

struct sia81xx_priv {
	struct device *dev;
	struct regmap *regmap;
	struct gpio_desc *enable_gpio;
	int chip_id;
};

static const struct reg_default sia81xx_defaults[] = {
	{ SIA81XX_REG_SYSCTRL, 0x00 },
	{ SIA81XX_REG_VOLUME,  0x00 },
};

static bool sia81xx_volatile_reg(struct device *dev, unsigned int reg)
{
	switch (reg) {
	case SIA81XX_REG_CHIPID:
	case SIA81XX_REG_STATUS:
		return true;
	default:
		return false;
	}
}

static const struct regmap_config sia81xx_regmap_config = {
	.reg_bits	= 8,
	.val_bits	= 8,
	.max_register	= SIA81XX_REG_MAX,
	.cache_type	= REGCACHE_RBTREE,
	.reg_defaults	= sia81xx_defaults,
	.num_reg_defaults = ARRAY_SIZE(sia81xx_defaults),
	.volatile_reg	= sia81xx_volatile_reg,
};

/* -31 dB (mute) .. 0 dB step 1 dB */
static const DECLARE_TLV_DB_SCALE(sia81xx_vol_tlv, -3100, 100, 1);

static const struct snd_kcontrol_new sia81xx_controls[] = {
	SOC_SINGLE_TLV("PA Volume", SIA81XX_REG_VOLUME, 0, 0x1F, 1,
		       sia81xx_vol_tlv),
};

static const struct snd_soc_dapm_widget sia81xx_dapm_widgets[] = {
	SND_SOC_DAPM_DAC("PA DAC", NULL, SIA81XX_REG_SYSCTRL, 0, 0),
	SND_SOC_DAPM_OUTPUT("OUT"),
};

static const struct snd_soc_dapm_route sia81xx_dapm_routes[] = {
	{ "OUT", NULL, "PA DAC" },
};

static int sia81xx_component_probe(struct snd_soc_component *comp)
{
	struct sia81xx_priv *p = snd_soc_component_get_drvdata(comp);

	if (p->enable_gpio) {
		gpiod_set_value_cansleep(p->enable_gpio, 1);
		usleep_range(1000, 1500);	/* tWAKE per datasheet */
	}

	return 0;
}

static void sia81xx_component_remove(struct snd_soc_component *comp)
{
	struct sia81xx_priv *p = snd_soc_component_get_drvdata(comp);

	regmap_update_bits(p->regmap, SIA81XX_REG_SYSCTRL,
			   SIA81XX_SYSCTRL_EN, 0);
	if (p->enable_gpio)
		gpiod_set_value_cansleep(p->enable_gpio, 0);
}

static const struct snd_soc_component_driver sia81xx_component = {
	.probe			= sia81xx_component_probe,
	.remove			= sia81xx_component_remove,
	.controls		= sia81xx_controls,
	.num_controls		= ARRAY_SIZE(sia81xx_controls),
	.dapm_widgets		= sia81xx_dapm_widgets,
	.num_dapm_widgets	= ARRAY_SIZE(sia81xx_dapm_widgets),
	.dapm_routes		= sia81xx_dapm_routes,
	.num_dapm_routes	= ARRAY_SIZE(sia81xx_dapm_routes),
};

static int sia81xx_mute_stream(struct snd_soc_dai *dai, int mute, int stream)
{
	struct sia81xx_priv *p = snd_soc_component_get_drvdata(dai->component);

	if (stream != SNDRV_PCM_STREAM_PLAYBACK)
		return 0;

	return regmap_update_bits(p->regmap, SIA81XX_REG_SYSCTRL,
				  SIA81XX_SYSCTRL_EN,
				  mute ? 0 : SIA81XX_SYSCTRL_EN);
}

static const struct snd_soc_dai_ops sia81xx_dai_ops = {
	.mute_stream	= sia81xx_mute_stream,
	.no_capture_mute = 1,
};

static struct snd_soc_dai_driver sia81xx_dai = {
	.name = "sia81xx-hifi",
	.playback = {
		.stream_name	= "Playback",
		.channels_min	= 1,
		.channels_max	= 2,
		.rates		= SNDRV_PCM_RATE_8000_192000,
		.formats	= SNDRV_PCM_FMTBIT_S16_LE |
				  SNDRV_PCM_FMTBIT_S24_LE |
				  SNDRV_PCM_FMTBIT_S32_LE,
	},
	.ops = &sia81xx_dai_ops,
};

static int sia81xx_i2c_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct sia81xx_priv *p;
	unsigned int id;
	int ret;

	p = devm_kzalloc(dev, sizeof(*p), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	p->dev = dev;

	p->enable_gpio = devm_gpiod_get_optional(dev, "enable", GPIOD_OUT_LOW);
	if (IS_ERR(p->enable_gpio))
		return dev_err_probe(dev, PTR_ERR(p->enable_gpio),
				     "enable gpio\n");

	if (p->enable_gpio) {
		gpiod_set_value_cansleep(p->enable_gpio, 1);
		usleep_range(1000, 1500);
	}

	p->regmap = devm_regmap_init_i2c(client, &sia81xx_regmap_config);
	if (IS_ERR(p->regmap))
		return dev_err_probe(dev, PTR_ERR(p->regmap), "regmap\n");

	ret = regmap_read(p->regmap, SIA81XX_REG_CHIPID, &id);
	if (ret) {
		dev_err(dev, "read chipid failed: %d\n", ret);
		return ret;
	}

	switch (id) {
	case SIA8101_CHIPID:
	case SIA8108_CHIPID:
	case SIA8109_CHIPID:
		break;
	default:
		dev_err(dev, "unknown sia81xx chip id 0x%02x\n", id);
		return -ENODEV;
	}

	p->chip_id = id;
	dev_info(dev, "sia81%02x detected (i2c addr 0x%02x)\n",
		 id, client->addr);

	i2c_set_clientdata(client, p);

	return devm_snd_soc_register_component(dev, &sia81xx_component,
					       &sia81xx_dai, 1);
}

static const struct of_device_id sia81xx_of_match[] = {
	{ .compatible = "si-in,sia81xx" },
	{ .compatible = "si-in,sia8101" },
	{ .compatible = "si-in,sia8108" },
	{ .compatible = "si-in,sia8109" },
	{}
};
MODULE_DEVICE_TABLE(of, sia81xx_of_match);

static const struct i2c_device_id sia81xx_i2c_id[] = {
	{ "sia81xx", 0 },
	{}
};
MODULE_DEVICE_TABLE(i2c, sia81xx_i2c_id);

static struct i2c_driver sia81xx_i2c_driver = {
	.driver = {
		.name		= "sia81xx-aether",
		.of_match_table	= sia81xx_of_match,
	},
	.probe		= sia81xx_i2c_probe,
	.id_table	= sia81xx_i2c_id,
};
module_i2c_driver(sia81xx_i2c_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("SIA81XX smart audio PA — minimal ASoC codec (RMX3171)");
MODULE_LICENSE("GPL");
