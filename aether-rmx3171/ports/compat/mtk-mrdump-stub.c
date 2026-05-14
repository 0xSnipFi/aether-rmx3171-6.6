// SPDX-License-Identifier: GPL-2.0
/*
 * Minimal MediaTek MRDUMP compatibility symbols for AETHER RMX3171.
 *
 * The full MTK AEE/IPANIC stack is not part of the current 6.6
 * GKI-oriented build, but several vendor modules keep optional hooks for
 * adding raw buffers to panic dumps. Exporting a small unsupported stub keeps
 * those modules loadable without pretending that MTK minidump is available.
 */

#include <linux/errno.h>
#include <linux/export.h>
#include <linux/types.h>

int mrdump_mini_add_extra_file(unsigned long vaddr, unsigned long paddr,
			       unsigned long size, const char *name)
{
	return -EOPNOTSUPP;
}
EXPORT_SYMBOL(mrdump_mini_add_extra_file);
