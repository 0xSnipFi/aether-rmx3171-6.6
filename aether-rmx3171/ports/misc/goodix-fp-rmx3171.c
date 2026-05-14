// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — Goodix GF3208 fingerprint kernel driver (skeleton).
 *
 * Slimmed port of Realme 4.14 `drivers/input/oppo_fp_drivers/
 * goodix_optical_fp/gf_spi.c` (~2500 LoC) down to ~400 LoC focused on:
 *   - SPI register + IRQ + reset GPIO
 *   - char device /dev/goodix_fp with vendor IOCTL ABI preserved verbatim
 *   - netlink event channel to userspace HAL
 *
 * IOCTL ABI MUST be byte-equivalent with 4.14 gf_spi.h — vendor blob
 * The vendor fingerprint HAL speaks these exact codes.
 *
 * Userspace HAL: device/realme/RMX3171/fingerprint/ (Goodix BiometricsFingerprint
 * @2.1 service binds to /dev/goodix_fp).
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/cdev.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/gpio/consumer.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/netlink.h>
#include <linux/of.h>
#include <linux/poll.h>
#include <linux/skbuff.h>
#include <linux/slab.h>
#include <linux/spi/spi.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <net/sock.h>

#define GF_NAME				"goodix_fp"
#define GF_DEV_MAJOR			0	/* dynamic */

/* IOCTL codes — preserved verbatim from 4.14 gf_spi.h.
 * DO NOT renumber; vendor blob depends on these exact values.
 */
#define GF_IOC_MAGIC			'g'
#define GF_IOC_INIT			_IOR(GF_IOC_MAGIC, 0, u8)
#define GF_IOC_EXIT			_IO(GF_IOC_MAGIC, 1)
#define GF_IOC_RESET			_IO(GF_IOC_MAGIC, 2)
#define GF_IOC_ENABLE_IRQ		_IO(GF_IOC_MAGIC, 3)
#define GF_IOC_DISABLE_IRQ		_IO(GF_IOC_MAGIC, 4)
#define GF_IOC_ENABLE_SPI_CLK		_IOW(GF_IOC_MAGIC, 5, u32)
#define GF_IOC_DISABLE_SPI_CLK		_IO(GF_IOC_MAGIC, 6)
#define GF_IOC_ENABLE_POWER		_IO(GF_IOC_MAGIC, 7)
#define GF_IOC_DISABLE_POWER		_IO(GF_IOC_MAGIC, 8)
#define GF_IOC_INPUT_KEY_EVENT		_IOW(GF_IOC_MAGIC, 9, struct gf_key)
#define GF_IOC_CHIP_INFO		_IOWR(GF_IOC_MAGIC, 10, u32)

#define GF_NETLINK_UNIT			25

/* Netlink message codes — preserved from 4.14 gf_netlink.c. */
#define GF_NETLINK_IRQ			1
#define GF_NETLINK_SCREEN_OFF		2
#define GF_NETLINK_SCREEN_ON		3

struct gf_key {
	u32 key;
	u32 value;
} __packed;

struct gf_priv {
	struct spi_device *spi;
	struct device *dev;
	dev_t devt;
	struct cdev cdev;
	struct class *class;
	struct gpio_desc *reset_gpio;
	struct gpio_desc *irq_gpio;
	int irq;
	struct sock *nl_sk;
	int nl_pid;
	bool irq_enabled;
	struct mutex lock;
};

static struct gf_priv *g_priv;

static void gf_send_netlink(struct gf_priv *p, u8 cmd)
{
	struct sk_buff *skb;
	struct nlmsghdr *nlh;
	u8 *data;

	if (!p->nl_sk || p->nl_pid == 0)
		return;

	skb = nlmsg_new(sizeof(u8), GFP_ATOMIC);
	if (!skb)
		return;

	nlh = nlmsg_put(skb, 0, 0, 0, sizeof(u8), 0);
	if (!nlh) {
		nlmsg_free(skb);
		return;
	}

	data = nlmsg_data(nlh);
	*data = cmd;

	NETLINK_CB(skb).portid = 0;
	NETLINK_CB(skb).dst_group = 0;
	netlink_unicast(p->nl_sk, skb, p->nl_pid, MSG_DONTWAIT);
}

static irqreturn_t gf_irq_handler(int irq, void *data)
{
	struct gf_priv *p = data;

	gf_send_netlink(p, GF_NETLINK_IRQ);
	return IRQ_HANDLED;
}

static int gf_open(struct inode *inode, struct file *file)
{
	file->private_data = g_priv;
	return 0;
}

static int gf_release(struct inode *inode, struct file *file)
{
	return 0;
}

static long gf_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct gf_priv *p = file->private_data;
	int ret = 0;

	mutex_lock(&p->lock);

	switch (cmd) {
	case GF_IOC_INIT:
		/* Userspace sets nl_pid via this; in 4.14 it's a u8 reply,
		 * we accept the same ABI.
		 */
		p->nl_pid = current->pid;
		break;

	case GF_IOC_EXIT:
		p->nl_pid = 0;
		break;

	case GF_IOC_RESET:
		if (p->reset_gpio) {
			gpiod_set_value_cansleep(p->reset_gpio, 0);
			msleep(3);
			gpiod_set_value_cansleep(p->reset_gpio, 1);
			msleep(50);
		}
		break;

	case GF_IOC_ENABLE_IRQ:
		if (!p->irq_enabled) {
			enable_irq(p->irq);
			p->irq_enabled = true;
		}
		break;

	case GF_IOC_DISABLE_IRQ:
		if (p->irq_enabled) {
			disable_irq(p->irq);
			p->irq_enabled = false;
		}
		break;

	case GF_IOC_ENABLE_POWER:
	case GF_IOC_DISABLE_POWER:
		/* Power is controlled via regulator-always-on or external PMIC
		 * GPIO; vendor HAL expects the ioctl to succeed silently.
		 */
		break;

	case GF_IOC_ENABLE_SPI_CLK:
	case GF_IOC_DISABLE_SPI_CLK:
		/* SPI clock is managed by SPI core in mainline; no-op. */
		break;

	case GF_IOC_INPUT_KEY_EVENT:
		/* Pass-through: vendor HAL injects KEY_F11 / KEY_VOLUMEUP etc.
		 * via this ioctl. We ignore in this skeleton (HAL uses uinput
		 * instead).
		 */
		break;

	case GF_IOC_CHIP_INFO:
		{
			u32 chip_id = 0x3208;	/* GF3208 family */

			if (copy_to_user((void __user *)arg, &chip_id,
					 sizeof(chip_id)))
				ret = -EFAULT;
			break;
		}

	default:
		ret = -ENOTTY;
	}

	mutex_unlock(&p->lock);
	return ret;
}

static const struct file_operations gf_fops = {
	.owner		= THIS_MODULE,
	.open		= gf_open,
	.release	= gf_release,
	.unlocked_ioctl	= gf_ioctl,
	.compat_ioctl	= gf_ioctl,
};

static void gf_netlink_recv(struct sk_buff *skb)
{
	struct gf_priv *p = g_priv;
	struct nlmsghdr *nlh;

	if (!p)
		return;

	nlh = nlmsg_hdr(skb);
	if (NLMSG_OK(nlh, skb->len))
		p->nl_pid = nlh->nlmsg_pid;
}

static int gf_probe(struct spi_device *spi)
{
	struct device *dev = &spi->dev;
	struct gf_priv *p;
	struct netlink_kernel_cfg cfg = {
		.input = gf_netlink_recv,
	};
	int ret;

	p = devm_kzalloc(dev, sizeof(*p), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	mutex_init(&p->lock);
	p->spi = spi;
	p->dev = dev;

	spi->bits_per_word = 8;
	spi->max_speed_hz = 8000000;	/* 8 MHz per 4.14 gf_spi.c */
	spi->mode = SPI_MODE_0;
	ret = spi_setup(spi);
	if (ret)
		return dev_err_probe(dev, ret, "spi_setup\n");

	p->reset_gpio = devm_gpiod_get_optional(dev, "fp-reset", GPIOD_OUT_LOW);
	if (IS_ERR(p->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(p->reset_gpio),
				     "reset gpio\n");

	p->irq_gpio = devm_gpiod_get_optional(dev, "fp-irq", GPIOD_IN);
	if (IS_ERR(p->irq_gpio))
		return dev_err_probe(dev, PTR_ERR(p->irq_gpio),
				     "irq gpio\n");

	if (p->irq_gpio) {
		p->irq = gpiod_to_irq(p->irq_gpio);
		if (p->irq < 0)
			return dev_err_probe(dev, p->irq,
					     "gpiod_to_irq\n");
	} else {
		p->irq = spi->irq;
	}

	ret = alloc_chrdev_region(&p->devt, 0, 1, GF_NAME);
	if (ret < 0)
		return ret;

	cdev_init(&p->cdev, &gf_fops);
	p->cdev.owner = THIS_MODULE;
	ret = cdev_add(&p->cdev, p->devt, 1);
	if (ret)
		goto err_unreg;

	p->class = class_create(GF_NAME);
	if (IS_ERR(p->class)) {
		ret = PTR_ERR(p->class);
		goto err_cdev;
	}

	if (IS_ERR(device_create(p->class, dev, p->devt, p, GF_NAME))) {
		ret = -ENODEV;
		goto err_class;
	}

	p->nl_sk = netlink_kernel_create(&init_net, GF_NETLINK_UNIT, &cfg);
	if (!p->nl_sk) {
		ret = -ENOMEM;
		goto err_dev;
	}

	ret = devm_request_threaded_irq(dev, p->irq, NULL, gf_irq_handler,
					IRQF_TRIGGER_RISING | IRQF_ONESHOT,
					GF_NAME, p);
	if (ret)
		goto err_nl;
	p->irq_enabled = true;

	g_priv = p;
	spi_set_drvdata(spi, p);
	dev_info(dev, "Goodix GF3208 fingerprint probed (irq=%d)\n", p->irq);
	return 0;

err_nl:
	netlink_kernel_release(p->nl_sk);
err_dev:
	device_destroy(p->class, p->devt);
err_class:
	class_destroy(p->class);
err_cdev:
	cdev_del(&p->cdev);
err_unreg:
	unregister_chrdev_region(p->devt, 1);
	return ret;
}

static void gf_remove(struct spi_device *spi)
{
	struct gf_priv *p = spi_get_drvdata(spi);

	if (!p)
		return;

	if (p->nl_sk)
		netlink_kernel_release(p->nl_sk);
	device_destroy(p->class, p->devt);
	class_destroy(p->class);
	cdev_del(&p->cdev);
	unregister_chrdev_region(p->devt, 1);
	g_priv = NULL;
}

static const struct of_device_id gf_of_match[] = {
	{ .compatible = "goodix,gf3208" },
	{ .compatible = "mediatek,goodix-fp" },
	{}
};
MODULE_DEVICE_TABLE(of, gf_of_match);

static const struct spi_device_id gf_spi_id[] = {
	{ "goodix_fp", 0 },
	{}
};
MODULE_DEVICE_TABLE(spi, gf_spi_id);

static struct spi_driver gf_driver = {
	.driver = {
		.name		= GF_NAME,
		.of_match_table	= gf_of_match,
	},
	.probe		= gf_probe,
	.remove		= gf_remove,
	.id_table	= gf_spi_id,
};
module_spi_driver(gf_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("Goodix GF3208 fingerprint (RMX3171, slim port)");
MODULE_LICENSE("GPL");
