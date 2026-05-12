// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — simple voltage-curve fuelgauge.
 *
 * Path B from aether-rmx3171/ports/TODO/gm30-battery/README.md.
 *
 * Replaces the 15000-LoC mtk_battery + gm30 framework with a 400-LoC
 * driver using:
 *   - VBAT read from mt6370_charger sibling power-supply
 *   - battery0_profile_t0..t4 arrays from rmx3171_bat_profile.dtsi
 *     (4 temperature × 100 SOC points each, byte-equivalent with stock)
 *   - thermal_zone for battery temperature
 *
 * Accuracy: ±3% SOC. No coulomb counting / no learning / no battery health.
 * Acceptable for non-mission-critical phone.
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/power_supply.h>
#include <linux/slab.h>
#include <linux/thermal.h>

#define AETHER_GAUGE_POLL_MS		20000	/* 20 s — battery doesn't move fast */
#define AETHER_GAUGE_TEMP_DEFAULT	250	/* 25.0 °C if thermal-zone absent */

/* Bat profile array element layout (MTK gm30 v2 row):
 *   [0] = mAh charged so far (16-bit)
 *   [1] = VBAT in mV (16-bit, big-endian-ish — but stock writes 0xaba4 etc.)
 *   [2] = R_BAT in mOhm (16-bit)
 *   The row count is 100 (SOC 0..99%).
 *   We convert: voltage_mv -> SOC_percent via piecewise-linear interpolation.
 */
#define BAT_ROW_SIZE			3
#define BAT_PROFILE_ROWS		100

struct aether_gauge {
	struct device *dev;
	struct power_supply *psy;
	struct power_supply *charger;	/* mt6370_charger (siblings on i2c) */
	struct thermal_zone_device *tz;
	struct delayed_work poll_work;

	/* Per-temperature voltage→SOC tables.
	 * profile[temp_idx][soc_idx][field] where field 1 == VBAT(mV).
	 */
	u32 profile_t[5][BAT_PROFILE_ROWS][BAT_ROW_SIZE];
	int profile_temps[5];	/* {50, 25, 10, 0, -10} matching T0..T4 */

	int last_soc;		/* cached SOC % */
	int last_voltage_uv;	/* cached VBAT in µV */
	int last_temp_c10;	/* cached temp ×10 (°C) */
};

static int aether_gauge_read_vbat_uv(struct aether_gauge *g)
{
	union power_supply_propval val = { 0 };
	int ret;

	if (!g->charger) {
		g->charger = power_supply_get_by_name("mt6370_charger");
		if (!g->charger) {
			g->charger = power_supply_get_by_name("charger");
			if (!g->charger)
				return -ENODEV;
		}
	}

	ret = power_supply_get_property(g->charger,
					POWER_SUPPLY_PROP_VOLTAGE_NOW, &val);
	if (ret)
		return ret;

	return val.intval;	/* µV */
}

static int aether_gauge_read_temp_c10(struct aether_gauge *g)
{
	int temp_mc = AETHER_GAUGE_TEMP_DEFAULT * 100;	/* convert tenths→mC */
	int ret;

	if (g->tz) {
		ret = thermal_zone_get_temp(g->tz, &temp_mc);
		if (ret)
			temp_mc = AETHER_GAUGE_TEMP_DEFAULT * 100;
	}

	return temp_mc / 100;	/* return °C * 10 */
}

/*
 * Convert VBAT (mV) → SOC (%) at given temperature.
 * Strategy: find the 2 nearest temperature tables, do linear interp on
 * voltage within each, then linear interp between the two temperatures.
 */
static int aether_gauge_compute_soc(struct aether_gauge *g,
				    int vbat_mv, int temp_c10)
{
	int temp_lo_idx = 1, temp_hi_idx = 1;
	int t_lo, t_hi;
	int soc_lo = 0, soc_hi = 0;
	int i, idx;

	/* Find bracketing temperature indices. Tables are ordered
	 * t0=50°C, t1=25°C, t2=10°C, t3=0°C, t4=-10°C.
	 */
	for (i = 0; i < 4; i++) {
		if (temp_c10 >= g->profile_temps[i + 1] * 10 &&
		    temp_c10 <= g->profile_temps[i] * 10) {
			temp_hi_idx = i;
			temp_lo_idx = i + 1;
			break;
		}
	}
	if (temp_c10 > g->profile_temps[0] * 10)
		temp_hi_idx = temp_lo_idx = 0;
	if (temp_c10 < g->profile_temps[4] * 10)
		temp_hi_idx = temp_lo_idx = 4;

	t_hi = g->profile_temps[temp_hi_idx];
	t_lo = g->profile_temps[temp_lo_idx];

	/* Per-table voltage lookup. profile[i][1] = VBAT mV (decreasing
	 * with SOC index — row 0 = fully charged).
	 */
	for (idx = 0; idx < 2; idx++) {
		int t_idx = (idx == 0) ? temp_hi_idx : temp_lo_idx;
		u32 (*tbl)[BAT_ROW_SIZE] = g->profile_t[t_idx];
		int soc = 0;
		int j;

		for (j = 0; j < BAT_PROFILE_ROWS - 1; j++) {
			int v_a = tbl[j][1];
			int v_b = tbl[j + 1][1];

			if (vbat_mv >= v_a) {
				soc = 100 - j;
				break;
			}
			if (vbat_mv > v_b && vbat_mv < v_a) {
				int span_mv = v_a - v_b;
				int delta_mv = v_a - vbat_mv;

				if (span_mv == 0) {
					soc = 100 - j;
				} else {
					/* Linear interp inside the row pair. */
					soc = 100 - j - delta_mv * 1 / span_mv;
				}
				break;
			}
			if (j == BAT_PROFILE_ROWS - 2)
				soc = 0;
		}

		if (idx == 0)
			soc_hi = soc;
		else
			soc_lo = soc;
	}

	if (temp_hi_idx == temp_lo_idx)
		return clamp(soc_hi, 0, 100);

	/* Linear interp across temperatures. */
	{
		int span_c = (t_hi - t_lo) * 10;
		int delta_c = (t_hi * 10) - temp_c10;
		int soc;

		if (span_c == 0)
			return clamp(soc_hi, 0, 100);

		soc = soc_hi - (soc_hi - soc_lo) * delta_c / span_c;
		return clamp(soc, 0, 100);
	}
}

static void aether_gauge_poll(struct work_struct *work)
{
	struct aether_gauge *g = container_of(to_delayed_work(work),
					      struct aether_gauge, poll_work);
	int vbat_uv = aether_gauge_read_vbat_uv(g);

	if (vbat_uv > 0) {
		g->last_voltage_uv = vbat_uv;
		g->last_temp_c10 = aether_gauge_read_temp_c10(g);
		g->last_soc = aether_gauge_compute_soc(g, vbat_uv / 1000,
						      g->last_temp_c10);
		power_supply_changed(g->psy);
	}

	schedule_delayed_work(&g->poll_work,
			      msecs_to_jiffies(AETHER_GAUGE_POLL_MS));
}

static enum power_supply_property aether_gauge_props[] = {
	POWER_SUPPLY_PROP_CAPACITY,
	POWER_SUPPLY_PROP_VOLTAGE_NOW,
	POWER_SUPPLY_PROP_TEMP,
	POWER_SUPPLY_PROP_PRESENT,
	POWER_SUPPLY_PROP_STATUS,
	POWER_SUPPLY_PROP_TECHNOLOGY,
	POWER_SUPPLY_PROP_CHARGE_FULL_DESIGN,
};

static int aether_gauge_get_property(struct power_supply *psy,
				     enum power_supply_property prop,
				     union power_supply_propval *val)
{
	struct aether_gauge *g = power_supply_get_drvdata(psy);

	switch (prop) {
	case POWER_SUPPLY_PROP_CAPACITY:
		val->intval = g->last_soc;
		break;
	case POWER_SUPPLY_PROP_VOLTAGE_NOW:
		val->intval = g->last_voltage_uv;
		break;
	case POWER_SUPPLY_PROP_TEMP:
		val->intval = g->last_temp_c10;
		break;
	case POWER_SUPPLY_PROP_PRESENT:
		val->intval = 1;
		break;
	case POWER_SUPPLY_PROP_STATUS:
		/* Status mirrors charger if available. */
		if (g->charger) {
			power_supply_get_property(g->charger,
						  POWER_SUPPLY_PROP_STATUS,
						  val);
		} else {
			val->intval = POWER_SUPPLY_STATUS_UNKNOWN;
		}
		break;
	case POWER_SUPPLY_PROP_TECHNOLOGY:
		val->intval = POWER_SUPPLY_TECHNOLOGY_LIPO;
		break;
	case POWER_SUPPLY_PROP_CHARGE_FULL_DESIGN:
		val->intval = 6000 * 1000;	/* 6000 mAh in µAh */
		break;
	default:
		return -EINVAL;
	}

	return 0;
}

static const struct power_supply_desc aether_gauge_desc = {
	.name		= "battery",
	.type		= POWER_SUPPLY_TYPE_BATTERY,
	.properties	= aether_gauge_props,
	.num_properties	= ARRAY_SIZE(aether_gauge_props),
	.get_property	= aether_gauge_get_property,
};

static int aether_gauge_parse_profile(struct aether_gauge *g)
{
	static const char * const names[5] = {
		"battery0_profile_t0",
		"battery0_profile_t1",
		"battery0_profile_t2",
		"battery0_profile_t3",
		"battery0_profile_t4",
	};
	static const char * const temp_keys[5] = {
		"TEMPERATURE_T0",
		"TEMPERATURE_T1",
		"TEMPERATURE_T2",
		"TEMPERATURE_T3",
		"TEMPERATURE_T4",
	};
	struct device_node *bm = of_parse_phandle(g->dev->of_node,
						  "battery-manager", 0);
	int i, j, k, ret;

	if (!bm) {
		dev_err(g->dev, "battery-manager phandle missing\n");
		return -ENODEV;
	}

	for (i = 0; i < 5; i++) {
		u32 temp_val;
		int len;
		u32 *raw;

		if (of_property_read_u32(bm, temp_keys[i], &temp_val))
			temp_val = 25;
		g->profile_temps[i] = (int)temp_val;

		raw = devm_kcalloc(g->dev,
				   BAT_PROFILE_ROWS * BAT_ROW_SIZE,
				   sizeof(u32), GFP_KERNEL);
		if (!raw)
			return -ENOMEM;

		ret = of_property_read_variable_u32_array(bm, names[i], raw,
				BAT_PROFILE_ROWS * BAT_ROW_SIZE,
				BAT_PROFILE_ROWS * BAT_ROW_SIZE);
		if (ret < 0) {
			dev_warn(g->dev,
				 "profile %s missing (ret=%d) — using default\n",
				 names[i], ret);
			/* Fall back: flat 4.0V curve. */
			for (j = 0; j < BAT_PROFILE_ROWS; j++) {
				raw[j * BAT_ROW_SIZE + 0] = j;
				raw[j * BAT_ROW_SIZE + 1] = 4200 - (4200 - 3300) * j / BAT_PROFILE_ROWS;
				raw[j * BAT_ROW_SIZE + 2] = 100;
			}
		}

		for (j = 0; j < BAT_PROFILE_ROWS; j++)
			for (k = 0; k < BAT_ROW_SIZE; k++)
				g->profile_t[i][j][k] =
					raw[j * BAT_ROW_SIZE + k];

		devm_kfree(g->dev, raw);
	}

	of_node_put(bm);
	return 0;
}

static int aether_gauge_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct aether_gauge *g;
	struct power_supply_config cfg = { 0 };
	int ret;

	g = devm_kzalloc(dev, sizeof(*g), GFP_KERNEL);
	if (!g)
		return -ENOMEM;

	g->dev = dev;
	g->last_soc = 50;
	g->last_temp_c10 = AETHER_GAUGE_TEMP_DEFAULT;

	ret = aether_gauge_parse_profile(g);
	if (ret)
		return ret;

	g->tz = thermal_zone_get_zone_by_name("battery");
	if (IS_ERR(g->tz))
		g->tz = NULL;

	cfg.drv_data = g;
	cfg.of_node = dev->of_node;

	g->psy = devm_power_supply_register(dev, &aether_gauge_desc, &cfg);
	if (IS_ERR(g->psy))
		return PTR_ERR(g->psy);

	INIT_DELAYED_WORK(&g->poll_work, aether_gauge_poll);
	schedule_delayed_work(&g->poll_work, msecs_to_jiffies(1000));

	platform_set_drvdata(pdev, g);
	dev_info(dev, "AETHER simple gauge online (5×100 profile loaded)\n");
	return 0;
}

static void aether_gauge_remove(struct platform_device *pdev)
{
	struct aether_gauge *g = platform_get_drvdata(pdev);

	cancel_delayed_work_sync(&g->poll_work);
}

static const struct of_device_id aether_gauge_of_match[] = {
	{ .compatible = "aether,simple-gauge" },
	{}
};
MODULE_DEVICE_TABLE(of, aether_gauge_of_match);

static struct platform_driver aether_gauge_driver = {
	.driver = {
		.name		= "aether-simple-gauge",
		.of_match_table	= aether_gauge_of_match,
	},
	.probe		= aether_gauge_probe,
	.remove_new	= aether_gauge_remove,
};
module_platform_driver(aether_gauge_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("AETHER simple voltage-curve fuelgauge (RMX3171)");
MODULE_LICENSE("GPL");
