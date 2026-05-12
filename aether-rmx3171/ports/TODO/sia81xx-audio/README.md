# sia81xx — Si-In-Chip smart audio PA

## What this is

External speaker amp on I2C/PDM. RMX3171 stock kernel ships SIA8101/8108/8109
variants (auto-detect). Vendor driver heavily coupled to 4.14 MTK ASoC AFE
+ `sound/soc/mediatek/`.

## Strategy: rewrite as minimal ASoC codec

Drop the AFE-side tuning_if, regmap helper layers, socket IPC. Keep only:
1. I2C probe + chip-id read.
2. Power-on / off sequence.
3. Volume control (digital gain register).
4. ASoC codec DAI hook to platform's pcm dai-link.

This brings 3500 LoC → ~400 LoC.

## Skeleton

```c
// sound/soc/codecs/sia81xx.c
#include <linux/i2c.h>
#include <linux/regmap.h>
#include <sound/soc.h>

#define SIA81XX_REG_CHIPID    0x00
#define SIA81XX_REG_SYSCTRL   0x01
#define SIA81XX_REG_VOLUME    0x06

static const struct regmap_config sia81xx_regmap = {
    .reg_bits = 8, .val_bits = 8,
    .max_register = 0x7F, .cache_type = REGCACHE_RBTREE,
};

struct sia81xx {
    struct regmap *regmap;
    struct gpio_desc *enable;
    int chip_id;  /* 0x01=8101, 0x08=8108, 0x09=8109 */
};

static int sia81xx_dai_mute(struct snd_soc_dai *dai, int mute, int stream)
{
    struct sia81xx *p = snd_soc_component_get_drvdata(dai->component);
    return regmap_update_bits(p->regmap, SIA81XX_REG_SYSCTRL,
                              BIT(0), mute ? 0 : BIT(0));
}

static const struct snd_soc_component_driver sia81xx_codec = {
    .controls = sia81xx_controls,
    .num_controls = ARRAY_SIZE(sia81xx_controls),
};

static struct snd_soc_dai_driver sia81xx_dai = {
    .name = "sia81xx-hifi",
    .playback = {
        .stream_name = "Playback",
        .channels_min = 1, .channels_max = 2,
        .rates = SNDRV_PCM_RATE_8000_192000,
        .formats = SNDRV_PCM_FMTBIT_S16_LE | SNDRV_PCM_FMTBIT_S24_LE,
    },
    .ops = &sia81xx_dai_ops,
};
```

Reference: `sound/soc/codecs/max98357a.c` (single-amp simple ASoC pattern).

## Register map — pull from staged

`sia81xx-audio/source/sia8101_regs.[ch]`, `sia8108_regs.[ch]`, `sia8109_regs.[ch]`
list every register address + value. Build a per-chip default-reg table.

## DT binding

```dts
&i2c1 {
    sia81xx@1c {
        compatible = "si-in,sia81xx";
        reg = <0x1c>;
        enable-gpios = <&pio 132 GPIO_ACTIVE_HIGH>;
    };
};
```

## Acceptance

- `aplay /system/media/audio/ringtones/Ring1.ogg` → audible from speaker.
- `tinymix -D 0 -t` shows volume controls.

## Status: P2, deferred. Audio works without it (lower volume, no smart PA EQ).
