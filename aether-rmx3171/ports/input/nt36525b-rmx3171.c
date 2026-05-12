// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — Novatek NT36525B touchscreen driver (skeleton).
 *
 * Slimmed port of Realme 4.14 `drivers/input/touchscreen/mediatek/NT36525B/
 * nt36xxx.c` (~3800 LoC vendor driver) down to ~500 LoC focused on:
 *   - I2C probe + reset
 *   - threaded IRQ → multi-touch report via input_mt
 *   - request_firmware() FW loading (nt36525b_fw.bin from /vendor/firmware)
 *
 * Drops from vendor:
 *   - proc_fs debug nodes (NVT_TOUCH_EXT_PROC)
 *   - ESD protect workqueue (NVT_TOUCH_ESD_PROTECT)
 *   - USB/headset state notifier callbacks
 *   - gesture wake-up (handled by userspace + DRM panel suspend hooks)
 *   - factory-mode self-test ioctls
 *
 * These can be reintroduced from 4.14 source incrementally if needed.
 *
 * Touch protocol (I2C addr 0x62, big-endian):
 *   Cmd 0x21: read event buffer (10 fingers × 6 bytes)
 *   Each finger frame: [id|status, x_hi, x_lo|y_hi, y_lo, pressure, area]
 *     status bits: 0=down, 1=move, 2=up
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/delay.h>
#include <linux/firmware.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/input/mt.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>

#define NVT_NAME		"nt36525b-rmx3171"
#define NVT_FW_NAME		"nt36525b_fw.bin"

#define NVT_MAX_FINGERS		10
#define NVT_EVENT_BUF_LEN	(1 + NVT_MAX_FINGERS * 6)

#define NVT_CMD_READ_EVENT	0x21

/* Touch panel native resolution (4.14 LCM_PARAMS). */
#define NVT_MAX_X		720
#define NVT_MAX_Y		1600

struct nvt_priv {
	struct i2c_client *client;
	struct input_dev *input;
	struct gpio_desc *reset_gpio;
	struct regulator *vdd;
	struct regulator *vio;
	bool enabled;
	u8 event_buf[NVT_EVENT_BUF_LEN];
};

static int nvt_i2c_read(struct nvt_priv *p, u8 cmd, u8 *buf, size_t len)
{
	struct i2c_msg msgs[2] = {
		{
			.addr	= p->client->addr,
			.flags	= 0,
			.len	= 1,
			.buf	= &cmd,
		},
		{
			.addr	= p->client->addr,
			.flags	= I2C_M_RD,
			.len	= len,
			.buf	= buf,
		},
	};
	int ret;

	ret = i2c_transfer(p->client->adapter, msgs, 2);
	if (ret < 0)
		return ret;
	return (ret == 2) ? 0 : -EIO;
}

static void nvt_reset(struct nvt_priv *p)
{
	if (!p->reset_gpio)
		return;

	gpiod_set_value_cansleep(p->reset_gpio, 1);
	usleep_range(1000, 1500);
	gpiod_set_value_cansleep(p->reset_gpio, 0);
	usleep_range(5000, 5500);
	gpiod_set_value_cansleep(p->reset_gpio, 1);
	msleep(20);
}

static int nvt_load_firmware(struct nvt_priv *p)
{
	const struct firmware *fw;
	int ret;

	ret = request_firmware(&fw, NVT_FW_NAME, &p->client->dev);
	if (ret) {
		dev_warn(&p->client->dev,
			 "firmware %s missing — using IC built-in FW (ret=%d)\n",
			 NVT_FW_NAME, ret);
		return 0;
	}

	dev_info(&p->client->dev, "loaded %s (%zu bytes)\n",
		 NVT_FW_NAME, fw->size);

	/* TODO_DEVICE_BOOT: actual FW upload requires NVT-specific bootloader
	 * protocol — sequence of I2C writes per nt36525b spec. Out of scope
	 * for this skeleton; using IC's built-in firmware works for basic
	 * touch report.
	 */

	release_firmware(fw);
	return 0;
}

static irqreturn_t nvt_irq_handler(int irq, void *data)
{
	struct nvt_priv *p = data;
	u8 *buf = p->event_buf;
	int ret, i;
	bool any_touch = false;

	ret = nvt_i2c_read(p, NVT_CMD_READ_EVENT, buf, NVT_EVENT_BUF_LEN);
	if (ret) {
		dev_err_ratelimited(&p->client->dev,
				    "event read failed: %d\n", ret);
		return IRQ_HANDLED;
	}

	/* buf[0] = touch status / packet header. buf[1..] = finger frames. */
	for (i = 0; i < NVT_MAX_FINGERS; i++) {
		u8 *f = &buf[1 + i * 6];
		u8 finger_id, status;
		u16 x, y, pressure;

		finger_id = (f[0] >> 3) & 0x1F;
		status = f[0] & 0x07;

		if (status == 0 && f[0] == 0)
			continue;	/* slot empty */

		input_mt_slot(p->input, finger_id);

		if (status == 1 || status == 2) {	/* down or move */
			x = ((u16)f[1] << 4) | (f[2] >> 4);
			y = ((u16)(f[2] & 0x0F) << 8) | f[3];
			pressure = f[4];

			input_mt_report_slot_state(p->input, MT_TOOL_FINGER,
						   true);
			input_report_abs(p->input, ABS_MT_POSITION_X, x);
			input_report_abs(p->input, ABS_MT_POSITION_Y, y);
			input_report_abs(p->input, ABS_MT_PRESSURE, pressure);
			input_report_abs(p->input, ABS_MT_TOUCH_MAJOR,
					 f[5] ? f[5] : 1);
			any_touch = true;
		} else {	/* up = 3, lift, etc. */
			input_mt_report_slot_inactive(p->input);
		}
	}

	input_mt_sync_frame(p->input);
	input_report_key(p->input, BTN_TOUCH, any_touch);
	input_sync(p->input);

	return IRQ_HANDLED;
}

static int nvt_power_on(struct nvt_priv *p)
{
	int ret;

	if (p->vdd) {
		ret = regulator_enable(p->vdd);
		if (ret)
			return ret;
	}
	if (p->vio) {
		ret = regulator_enable(p->vio);
		if (ret)
			goto err_vdd;
	}
	usleep_range(5000, 5500);

	nvt_reset(p);
	return 0;

err_vdd:
	if (p->vdd)
		regulator_disable(p->vdd);
	return ret;
}

static void nvt_power_off(struct nvt_priv *p)
{
	if (p->reset_gpio)
		gpiod_set_value_cansleep(p->reset_gpio, 0);
	if (p->vio)
		regulator_disable(p->vio);
	if (p->vdd)
		regulator_disable(p->vdd);
}

static int nvt_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct nvt_priv *p;
	int ret;

	if (!i2c_check_functionality(client->adapter,
				     I2C_FUNC_I2C | I2C_FUNC_SMBUS_BYTE_DATA))
		return -EIO;

	p = devm_kzalloc(dev, sizeof(*p), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	p->client = client;
	i2c_set_clientdata(client, p);

	p->vdd = devm_regulator_get_optional(dev, "vdd");
	if (IS_ERR(p->vdd)) {
		if (PTR_ERR(p->vdd) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		p->vdd = NULL;
	}
	p->vio = devm_regulator_get_optional(dev, "vio");
	if (IS_ERR(p->vio)) {
		if (PTR_ERR(p->vio) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		p->vio = NULL;
	}

	p->reset_gpio = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(p->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(p->reset_gpio),
				     "reset gpio\n");

	ret = nvt_power_on(p);
	if (ret)
		return ret;

	ret = nvt_load_firmware(p);
	if (ret)
		goto err_off;

	p->input = devm_input_allocate_device(dev);
	if (!p->input) {
		ret = -ENOMEM;
		goto err_off;
	}

	p->input->name = "Novatek NT36525B Touch (RMX3171)";
	p->input->phys = "rmx3171-touch/input0";
	p->input->id.bustype = BUS_I2C;
	p->input->dev.parent = dev;

	__set_bit(EV_SYN, p->input->evbit);
	__set_bit(EV_KEY, p->input->evbit);
	__set_bit(EV_ABS, p->input->evbit);
	__set_bit(BTN_TOUCH, p->input->keybit);

	input_set_abs_params(p->input, ABS_MT_POSITION_X, 0, NVT_MAX_X, 0, 0);
	input_set_abs_params(p->input, ABS_MT_POSITION_Y, 0, NVT_MAX_Y, 0, 0);
	input_set_abs_params(p->input, ABS_MT_PRESSURE, 0, 255, 0, 0);
	input_set_abs_params(p->input, ABS_MT_TOUCH_MAJOR, 0, 255, 0, 0);

	ret = input_mt_init_slots(p->input, NVT_MAX_FINGERS,
				  INPUT_MT_DIRECT | INPUT_MT_DROP_UNUSED);
	if (ret)
		goto err_off;

	ret = input_register_device(p->input);
	if (ret)
		goto err_off;

	ret = devm_request_threaded_irq(dev, client->irq, NULL,
					nvt_irq_handler,
					IRQF_TRIGGER_FALLING | IRQF_ONESHOT,
					client->name, p);
	if (ret) {
		dev_err(dev, "request_irq failed: %d\n", ret);
		goto err_off;
	}

	p->enabled = true;
	dev_info(dev, "NT36525B touch probed (irq=%d)\n", client->irq);
	return 0;

err_off:
	nvt_power_off(p);
	return ret;
}

static void nvt_remove(struct i2c_client *client)
{
	struct nvt_priv *p = i2c_get_clientdata(client);

	nvt_power_off(p);
}

static int __maybe_unused nvt_suspend(struct device *dev)
{
	struct nvt_priv *p = dev_get_drvdata(dev);

	disable_irq(p->client->irq);
	return 0;
}

static int __maybe_unused nvt_resume(struct device *dev)
{
	struct nvt_priv *p = dev_get_drvdata(dev);

	enable_irq(p->client->irq);
	return 0;
}

static SIMPLE_DEV_PM_OPS(nvt_pm_ops, nvt_suspend, nvt_resume);

static const struct of_device_id nvt_of_match[] = {
	{ .compatible = "novatek,nt36525b" },
	{ .compatible = "realme,rmx3171-touch" },
	{}
};
MODULE_DEVICE_TABLE(of, nvt_of_match);

static const struct i2c_device_id nvt_i2c_id[] = {
	{ "nt36525b", 0 },
	{}
};
MODULE_DEVICE_TABLE(i2c, nvt_i2c_id);

static struct i2c_driver nvt_driver = {
	.driver = {
		.name		= NVT_NAME,
		.of_match_table	= nvt_of_match,
		.pm		= &nvt_pm_ops,
	},
	.probe		= nvt_probe,
	.remove		= nvt_remove,
	.id_table	= nvt_i2c_id,
};
module_i2c_driver(nvt_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("Novatek NT36525B touchscreen (RMX3171, slim port)");
MODULE_FIRMWARE(NVT_FW_NAME);
MODULE_LICENSE("GPL");
