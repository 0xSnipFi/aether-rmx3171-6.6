# AETHER RMX3171 Android 16 legacy-boot layout
#
# Real Narzo 30A / RMX3171 stock GPT:
# - boot header v2
# - boot + dtbo physical partitions
# - no physical vendor_boot
# - no physical init_boot
# - no A/B slot suffix
#
# This file keeps Android 16 userspace/dynamic-super support while packaging
# the kernel through the stock boot.img/dtbo.img flow. This is the production
# default for real hardware. BoardConfigA16.mk remains available only for
# explicit AETHER_BOOT_HEADER_VERSION=4 experiments.

# Keep stock boot v2 parameters from BoardConfig.mk.
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_USES_GENERIC_KERNEL_IMAGE :=
BOARD_USES_VENDOR_BOOTIMAGE :=
BOARD_BUILD_VENDOR_BOOT_IMAGE :=
BOARD_USES_INIT_BOOT_IMAGE :=

# Android 16 logical module separation inside super. These are logical
# partitions, not physical GPT partitions. Custom super.img must contain them.
BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE := 268435456
BOARD_VENDOR_DLKM_MODULES_LOAD := \
    $(shell cat $(DEVICE_PATH)/../../../../aether-rmx3171/modules/vendor_dlkm.modules.load 2>/dev/null | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')

BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE := 134217728
BOARD_SYSTEM_DLKM_MODULES_LOAD := \
    $(shell cat $(DEVICE_PATH)/../../../../aether-rmx3171/modules/system_dlkm.modules.load 2>/dev/null | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')

BOARD_MAIN_PARTITION_LIST := product vendor system system_ext odm vendor_dlkm system_dlkm

# DTBO is a real stock partition on RMX3171.
BOARD_KERNEL_DTBOIMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/../../../../out/dtbo.img

# AVB chains for logical dlkm partitions. Development builds may still disable
# verification with unlocked bootloader flags; production builds should provide
# AETHER_AVB_KEY_PATH outside git.
BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm
BOARD_AVB_VBMETA_VENDOR := vendor odm vendor_dlkm

BOARD_AVB_VENDOR_DLKM_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_VENDOR_DLKM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VENDOR_DLKM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VENDOR_DLKM_ROLLBACK_INDEX_LOCATION := 5

BOARD_AVB_SYSTEM_DLKM_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_SYSTEM_DLKM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_DLKM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_SYSTEM_DLKM_ROLLBACK_INDEX_LOCATION := 6

# Android 16 identity; bootconfig partition is not present on stock RMX3171, so
# critical androidboot props stay on BOARD_KERNEL_CMDLINE for this layout.
BOARD_KERNEL_CMDLINE += androidboot.hardware=mt6768
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=bootdevice,11230000.mmc
BOARD_KERNEL_CMDLINE += androidboot.selinux=enforcing
BOARD_KERNEL_CMDLINE += androidboot.veritymode=enforcing
BOARD_KERNEL_CMDLINE += androidboot.gki.kernel_release_string=6.6.50-AETHER-X-RMX3171-A16+

PRODUCT_TARGET_VNDK_VERSION := 35
PRODUCT_SHIPPING_API_LEVEL := 35

# Non-A/B recovery-based device. Do not advertise virtual A/B or partitions the
# physical GPT cannot flash.
AB_OTA_UPDATER := false
AB_OTA_PARTITIONS :=
