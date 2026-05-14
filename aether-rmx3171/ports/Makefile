# SPDX-License-Identifier: GPL-2.0
# AETHER RMX3171 ports — top-level Makefile
#
# Symlink this dir into kernel-6.6/drivers/aether/ then add to
# kernel-6.6/drivers/Makefile:
#   obj-y += aether/

obj-$(CONFIG_AETHER_PANEL_ILT9881H_RMX3171) += panel/panel-ilt9881h-rmx3171.o
obj-$(CONFIG_AETHER_SIMPLE_GAUGE)           += power/aether-simple-gauge.o
obj-$(CONFIG_AETHER_SND_SOC_SIA81XX)        += audio/sia81xx-aether.o
obj-$(CONFIG_AETHER_PINCTRL_MT6768)         += pinctrl/pinctrl-mt6768.o
obj-$(CONFIG_AETHER_TOUCHSCREEN_NT36525B)   += input/nt36525b-rmx3171.o
obj-$(CONFIG_AETHER_GOODIX_FP)              += misc/goodix-fp-rmx3171.o
obj-$(CONFIG_AETHER_MT6370_PE)              += power/mt6370-pe-rmx3171.o
obj-$(CONFIG_AETHER_FM_MT6631)              += connectivity/fm-mt6631-aether.o
obj-$(CONFIG_AETHER_MTK_MRDUMP_STUB)        += compat/mtk-mrdump-stub.o

ccflags-y += -I$(srctree)/drivers/pinctrl/mediatek
