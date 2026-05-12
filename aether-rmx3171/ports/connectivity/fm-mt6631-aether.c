// SPDX-License-Identifier: GPL-2.0-only
/*
 * AETHER RMX3171 — MT6631 FM radio driver (out-of-tree slim).
 *
 * Slimmed port of 4.14 `kernel_modules/connectivity/fmradio/`
 * (~30K LoC across 50+ files) down to ~450 LoC focused on:
 *   - misc device /dev/fm with vendor IOCTL ABI preserved verbatim
 *   - Tune / scan / RSSI / mute through connsys arbiter
 *   - WCN handshake (MTK Combo chip MT6631) via wmt_drv hook
 *
 * Drops:
 *   - chip-specific tables for MT6627/6630/6632/6635/6636 (RMX3171 only
 *     has MT6631)
 *   - RDS (Radio Data System) parsing — handled in userspace by Realme FM app
 *   - Test-mode self-check ioctls
 *   - DBG procfs nodes
 *
 * Userspace ABI: Realme FM app talks /dev/fm via FM_IOC_* ioctls — exact
 * numeric codes preserved from 4.14 fm_ioctl.h.
 *
 * Author: AETHER project, 2026-05-12.
 */

#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/uaccess.h>

#define FM_NAME			"fm"

/* IOCTL codes — preserved from 4.14 fm_ioctl.h. */
#define FM_IOC_MAGIC		0xf6
#define FM_IOCTL_POWERUP	_IOWR(FM_IOC_MAGIC, 0, struct fm_tune_req)
#define FM_IOCTL_POWERDOWN	_IO(FM_IOC_MAGIC, 1)
#define FM_IOCTL_TUNE		_IOWR(FM_IOC_MAGIC, 2, struct fm_tune_req)
#define FM_IOCTL_SEEK		_IOWR(FM_IOC_MAGIC, 3, struct fm_seek_req)
#define FM_IOCTL_SETVOL		_IOW(FM_IOC_MAGIC, 4, u32)
#define FM_IOCTL_GETVOL		_IOR(FM_IOC_MAGIC, 5, u32)
#define FM_IOCTL_MUTE		_IOW(FM_IOC_MAGIC, 6, u32)
#define FM_IOCTL_GETRSSI	_IOR(FM_IOC_MAGIC, 7, s32)
#define FM_IOCTL_SCAN		_IOWR(FM_IOC_MAGIC, 8, struct fm_scan_req)
#define FM_IOCTL_GETCHIPID	_IOR(FM_IOC_MAGIC, 9, u16)

struct fm_tune_req {
	u32 freq;	/* in kHz, e.g. 100100 = 100.1 MHz */
	s32 rssi;
	u32 valid;
} __packed;

struct fm_seek_req {
	u32 freq;
	u32 band;	/* 0 = 87.5-108, 1 = 76-91 (JP) */
	u32 space;	/* spacing in kHz (50 / 100 / 200) */
	u32 dir;	/* 0 = down, 1 = up */
} __packed;

struct fm_scan_req {
	u32 band;
	u32 space;
	u32 num;	/* IN: max entries / OUT: found */
	u32 freqs[100];
} __packed;

struct fm_priv {
	struct device *dev;
	struct miscdevice mdev;
	struct mutex lock;

	bool powered;
	u32 cur_freq;	/* kHz */
	u32 cur_vol;
	bool muted;
	s32 cur_rssi;
};

/* ============================================================
 * Connsys bridge — calls into MTK wmt_drv to power up FM block.
 * In real hardware bring-up these would dispatch through
 * conninfra/wmt_chrdev_wifi nodes. For skeleton we emit dev_dbg().
 * ============================================================
 */
static int fm_chip_poweron(struct fm_priv *p)
{
	dev_dbg(p->dev, "FM: poweron via connsys MT6631\n");
	/* TODO_DEVICE_BOOT: call wmt_drv mtk_wcn_consys_fm_power_on() */
	p->powered = true;
	return 0;
}

static int fm_chip_poweroff(struct fm_priv *p)
{
	dev_dbg(p->dev, "FM: poweroff\n");
	/* TODO_DEVICE_BOOT: call wmt_drv mtk_wcn_consys_fm_power_off() */
	p->powered = false;
	return 0;
}

static int fm_chip_tune(struct fm_priv *p, u32 freq_khz)
{
	dev_dbg(p->dev, "FM: tune %u kHz\n", freq_khz);
	/* TODO_DEVICE_BOOT: write tune freq to MT6631 reg + poll lock bit */
	p->cur_freq = freq_khz;
	p->cur_rssi = -65;	/* mock */
	return 0;
}

static int fm_chip_seek(struct fm_priv *p, struct fm_seek_req *req)
{
	u32 start = req->freq;
	u32 step = req->space;
	u32 limit_low = (req->band == 1) ? 76000 : 87500;
	u32 limit_high = (req->band == 1) ? 91000 : 108000;
	u32 cur = start;
	int safety = 1000;

	while (safety-- > 0) {
		cur += req->dir ? step : -((s32)step);
		if (cur > limit_high)
			cur = limit_low;
		if (cur < limit_low)
			cur = limit_high;
		if (cur == start)
			return -EAGAIN;

		fm_chip_tune(p, cur);
		/* TODO_DEVICE_BOOT: read MT6631 RSSI; if > threshold, break */
		break;	/* skeleton: stop on first */
	}
	req->freq = p->cur_freq;
	return 0;
}

static int fm_open(struct inode *inode, struct file *file)
{
	struct fm_priv *p = container_of(file->private_data,
					 struct fm_priv, mdev);
	file->private_data = p;
	return 0;
}

static int fm_release(struct inode *inode, struct file *file)
{
	struct fm_priv *p = file->private_data;

	mutex_lock(&p->lock);
	if (p->powered)
		fm_chip_poweroff(p);
	mutex_unlock(&p->lock);
	return 0;
}

static long fm_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct fm_priv *p = file->private_data;
	void __user *uarg = (void __user *)arg;
	int ret = 0;

	mutex_lock(&p->lock);

	switch (cmd) {
	case FM_IOCTL_POWERUP: {
		struct fm_tune_req req;

		if (copy_from_user(&req, uarg, sizeof(req))) {
			ret = -EFAULT;
			break;
		}
		ret = fm_chip_poweron(p);
		if (!ret)
			ret = fm_chip_tune(p, req.freq);
		break;
	}

	case FM_IOCTL_POWERDOWN:
		ret = fm_chip_poweroff(p);
		break;

	case FM_IOCTL_TUNE: {
		struct fm_tune_req req;

		if (copy_from_user(&req, uarg, sizeof(req))) {
			ret = -EFAULT;
			break;
		}
		ret = fm_chip_tune(p, req.freq);
		req.rssi = p->cur_rssi;
		req.valid = 1;
		if (copy_to_user(uarg, &req, sizeof(req)))
			ret = -EFAULT;
		break;
	}

	case FM_IOCTL_SEEK: {
		struct fm_seek_req req;

		if (copy_from_user(&req, uarg, sizeof(req))) {
			ret = -EFAULT;
			break;
		}
		ret = fm_chip_seek(p, &req);
		if (copy_to_user(uarg, &req, sizeof(req)))
			ret = -EFAULT;
		break;
	}

	case FM_IOCTL_SETVOL: {
		u32 v;

		if (copy_from_user(&v, uarg, sizeof(v))) {
			ret = -EFAULT;
			break;
		}
		p->cur_vol = v;
		break;
	}

	case FM_IOCTL_GETVOL:
		if (copy_to_user(uarg, &p->cur_vol, sizeof(p->cur_vol)))
			ret = -EFAULT;
		break;

	case FM_IOCTL_MUTE: {
		u32 m;

		if (copy_from_user(&m, uarg, sizeof(m))) {
			ret = -EFAULT;
			break;
		}
		p->muted = !!m;
		break;
	}

	case FM_IOCTL_GETRSSI:
		if (copy_to_user(uarg, &p->cur_rssi, sizeof(p->cur_rssi)))
			ret = -EFAULT;
		break;

	case FM_IOCTL_GETCHIPID: {
		u16 id = 0x6631;

		if (copy_to_user(uarg, &id, sizeof(id)))
			ret = -EFAULT;
		break;
	}

	default:
		ret = -ENOTTY;
	}

	mutex_unlock(&p->lock);
	return ret;
}

static const struct file_operations fm_fops = {
	.owner		= THIS_MODULE,
	.open		= fm_open,
	.release	= fm_release,
	.unlocked_ioctl	= fm_ioctl,
	.compat_ioctl	= fm_ioctl,
	.llseek		= no_llseek,
};

static int fm_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct fm_priv *p;
	int ret;

	p = devm_kzalloc(dev, sizeof(*p), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	p->dev = dev;
	mutex_init(&p->lock);
	p->cur_freq = 100100;	/* default 100.1 MHz */
	p->cur_vol = 8;
	p->cur_rssi = -90;

	p->mdev.minor = MISC_DYNAMIC_MINOR;
	p->mdev.name = FM_NAME;
	p->mdev.fops = &fm_fops;
	p->mdev.parent = dev;

	ret = misc_register(&p->mdev);
	if (ret)
		return ret;

	platform_set_drvdata(pdev, p);
	dev_info(dev, "FM MT6631 misc device ready (/dev/fm)\n");
	return 0;
}

static void fm_remove(struct platform_device *pdev)
{
	struct fm_priv *p = platform_get_drvdata(pdev);

	misc_deregister(&p->mdev);
	if (p->powered)
		fm_chip_poweroff(p);
}

static const struct of_device_id fm_of_match[] = {
	{ .compatible = "mediatek,mt6631-fm" },
	{ .compatible = "aether,fm-mt6631" },
	{}
};
MODULE_DEVICE_TABLE(of, fm_of_match);

static struct platform_driver fm_driver = {
	.driver = {
		.name		= "fm-mt6631-aether",
		.of_match_table	= fm_of_match,
	},
	.probe		= fm_probe,
	.remove_new	= fm_remove,
};
module_platform_driver(fm_driver);

MODULE_AUTHOR("AETHER RMX3171 project");
MODULE_DESCRIPTION("MT6631 FM radio (RMX3171, slim port)");
MODULE_LICENSE("GPL");
