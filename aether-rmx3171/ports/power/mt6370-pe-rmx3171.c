// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — MT6370 Pump Express Plus (PE+) charging handshake.
 *
 * Realme Narzo 30A ships with 18W Quick Charge adapter (9V / 2A via
 * MediaTek Pump Express Plus). Mainline `mt6370_charger.ko` only does
 * 5V/2A negotiation; PE+ requires PMIC-level voltage-pulse pattern to
 * make the adapter switch output to 9V.
 *
 * This driver ports the PE+ state machine from Realme 4.14:
 *   drivers/power/mediatek/charger/mtk_pe.c   (~1500 LoC)
 * Slimmed to ~350 LoC by dropping PE 2.0/4.0 paths (RMX3171 adapter only
 * supports PE+), telemetry, and userspace IOCTL.
 *
 * Algorithm: send 5 voltage pulses (5V→7V) within tight timing window,
 * adapter recognizes pattern, switches Vbus to 9V. Battery then takes
 * 9V/2A = 18W instead of 5V/2A = 10W.
 *
 * Bind:  power_supply_get_by_name("mt6370_charger") + AC-detect notifier.
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/delay.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/power_supply.h>
#include <linux/slab.h>
#include <linux/workqueue.h>

#define PE_TARGET_VBUS_UV		9000000		/* 9 V */
#define PE_INITIAL_VBUS_UV		5000000		/* 5 V */
#define PE_PULSE_VBUS_UV		7000000		/* 7 V pulse step */
#define PE_PULSE_COUNT			5
#define PE_PULSE_GAP_US			60		/* µs between pulses */
#define PE_RETRY_MAX			3

/* MT6370 reg map (subset).  Full map: vendor-modules/.../mt6370.h */
#define MT6370_REG_BUCK_CTRL2		0x12
#define MT6370_REG_CHG_CTRL2		0x18
#define MT6370_REG_CHG_CTRL19		0x29
#define MT6370_BIT_VBUS_OVP_EN		BIT(7)

enum pe_state {
	PE_STATE_IDLE,
	PE_STATE_DETECTING,
	PE_STATE_NEGOTIATING,
	PE_STATE_RUNNING,
	PE_STATE_FAILED,
};

struct mt6370_pe {
	struct device *dev;
	struct power_supply *charger;
	struct notifier_block psy_nb;
	struct delayed_work negotiate_work;
	struct mutex lock;
	enum pe_state state;
	int retry_count;
	bool ac_present;
};

static int pe_set_charger_voltage(struct mt6370_pe *p, int uV)
{
	union power_supply_propval val = {
		.intval = uV,
	};

	return power_supply_set_property(p->charger,
					 POWER_SUPPLY_PROP_VOLTAGE_NOW, &val);
}

static int pe_get_vbus(struct mt6370_pe *p)
{
	union power_supply_propval val = { 0 };
	int ret;

	ret = power_supply_get_property(p->charger,
					POWER_SUPPLY_PROP_VOLTAGE_NOW, &val);
	if (ret)
		return ret;
	return val.intval;
}

static int pe_send_pulse_pattern(struct mt6370_pe *p)
{
	int i, ret;

	dev_dbg(p->dev, "PE+: send %d pulses\n", PE_PULSE_COUNT);

	for (i = 0; i < PE_PULSE_COUNT; i++) {
		ret = pe_set_charger_voltage(p, PE_PULSE_VBUS_UV);
		if (ret)
			return ret;
		usleep_range(PE_PULSE_GAP_US, PE_PULSE_GAP_US + 10);

		ret = pe_set_charger_voltage(p, PE_INITIAL_VBUS_UV);
		if (ret)
			return ret;
		usleep_range(PE_PULSE_GAP_US, PE_PULSE_GAP_US + 10);
	}

	return 0;
}

static int pe_check_adapter_response(struct mt6370_pe *p)
{
	int vbus;

	msleep(50);
	vbus = pe_get_vbus(p);
	if (vbus < 0)
		return vbus;

	if (vbus >= PE_TARGET_VBUS_UV - 500000 &&
	    vbus <= PE_TARGET_VBUS_UV + 500000) {
		dev_info(p->dev, "PE+: adapter switched to 9V (vbus=%d µV)\n",
			 vbus);
		return 0;
	}

	dev_info(p->dev, "PE+: adapter stayed at %d µV (no PE+ support)\n",
		 vbus);
	return -ENODEV;
}

static void pe_negotiate_work(struct work_struct *w)
{
	struct mt6370_pe *p = container_of(to_delayed_work(w),
					    struct mt6370_pe, negotiate_work);
	int ret;

	mutex_lock(&p->lock);

	if (!p->ac_present || p->state == PE_STATE_RUNNING ||
	    p->state == PE_STATE_FAILED) {
		mutex_unlock(&p->lock);
		return;
	}

	p->state = PE_STATE_NEGOTIATING;
	dev_info(p->dev, "PE+: negotiation attempt %d/%d\n",
		 p->retry_count + 1, PE_RETRY_MAX);

	ret = pe_send_pulse_pattern(p);
	if (ret) {
		dev_warn(p->dev, "PE+: pulse send failed: %d\n", ret);
		goto retry;
	}

	ret = pe_check_adapter_response(p);
	if (ret == 0) {
		p->state = PE_STATE_RUNNING;
		mutex_unlock(&p->lock);
		return;
	}

retry:
	p->retry_count++;
	if (p->retry_count >= PE_RETRY_MAX) {
		p->state = PE_STATE_FAILED;
		dev_info(p->dev,
			 "PE+: handshake failed after %d tries; standard 5V/2A\n",
			 PE_RETRY_MAX);
	} else {
		p->state = PE_STATE_DETECTING;
		schedule_delayed_work(&p->negotiate_work,
				      msecs_to_jiffies(2000));
	}
	mutex_unlock(&p->lock);
}

static int pe_psy_notify(struct notifier_block *nb,
			 unsigned long event, void *data)
{
	struct mt6370_pe *p = container_of(nb, struct mt6370_pe, psy_nb);
	struct power_supply *psy = data;
	union power_supply_propval val = { 0 };
	int ret;
	bool ac_now;

	if (event != PSY_EVENT_PROP_CHANGED || psy != p->charger)
		return NOTIFY_OK;

	ret = power_supply_get_property(psy, POWER_SUPPLY_PROP_ONLINE, &val);
	if (ret)
		return NOTIFY_OK;

	ac_now = !!val.intval;

	mutex_lock(&p->lock);
	if (ac_now && !p->ac_present) {
		p->ac_present = true;
		p->state = PE_STATE_DETECTING;
		p->retry_count = 0;
		schedule_delayed_work(&p->negotiate_work,
				      msecs_to_jiffies(500));
	} else if (!ac_now && p->ac_present) {
		p->ac_present = false;
		p->state = PE_STATE_IDLE;
		cancel_delayed_work(&p->negotiate_work);
	}
	mutex_unlock(&p->lock);

	return NOTIFY_OK;
}

static int mt6370_pe_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct mt6370_pe *p;
	int ret;

	p = devm_kzalloc(dev, sizeof(*p), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	p->dev = dev;
	mutex_init(&p->lock);
	INIT_DELAYED_WORK(&p->negotiate_work, pe_negotiate_work);

	p->charger = power_supply_get_by_name("mt6370_charger");
	if (!p->charger)
		p->charger = power_supply_get_by_name("mtk-master-charger");
	if (!p->charger) {
		dev_warn(dev, "charger psy not present — defer\n");
		return -EPROBE_DEFER;
	}

	p->psy_nb.notifier_call = pe_psy_notify;
	ret = power_supply_reg_notifier(&p->psy_nb);
	if (ret) {
		power_supply_put(p->charger);
		return ret;
	}

	platform_set_drvdata(pdev, p);
	dev_info(dev, "MT6370 PE+ ready (target 9V/2A = 18W)\n");
	return 0;
}

static void mt6370_pe_remove(struct platform_device *pdev)
{
	struct mt6370_pe *p = platform_get_drvdata(pdev);

	cancel_delayed_work_sync(&p->negotiate_work);
	power_supply_unreg_notifier(&p->psy_nb);
	power_supply_put(p->charger);
}

static const struct of_device_id mt6370_pe_of_match[] = {
	{ .compatible = "aether,mt6370-pe" },
	{}
};
MODULE_DEVICE_TABLE(of, mt6370_pe_of_match);

static struct platform_driver mt6370_pe_driver = {
	.driver = {
		.name		= "mt6370-pe-rmx3171",
		.of_match_table	= mt6370_pe_of_match,
	},
	.probe		= mt6370_pe_probe,
	.remove_new	= mt6370_pe_remove,
};
module_platform_driver(mt6370_pe_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("MT6370 Pump Express Plus (RMX3171 18W Quick Charge)");
MODULE_LICENSE("GPL");
