# AETHER RMX3171 — Android 16 BoardConfig overlay
#
# Applies on top of BoardConfig.mk to bump to A16 boot/vendor_boot/init_boot/
# vendor_dlkm layout. Do not include this file when targeting an A11/A12
# legacy bootloader; use plain BoardConfig.mk in that case.
#
# Include order in AndroidProducts: BoardConfig.mk first, then this file.
#
# Bring this in via:
#   ifeq ($(AETHER_BOOT_HEADER_VERSION),4)
#   include $(DEVICE_PATH)/BoardConfigA16.mk
#   endif

# ============================================================
# Bootimage layout — A12+ vendor_boot split
# ============================================================
# Override v2 from base
BOARD_BOOT_HEADER_VERSION := 4

# Boot image now carries only generic ramdisk + kernel.
# Vendor ramdisk + DTB + first-stage modules go to vendor_boot.
BOARD_INCLUDE_DTB_IN_BOOTIMG :=
BOARD_USES_VENDOR_BOOTIMAGE := true
BOARD_BUILD_VENDOR_BOOT_IMAGE := true
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864     # 64 MB
BOARD_INCLUDE_RECOVERY_DTBO := false                  # DTBO now in vendor_boot
BOARD_VENDOR_BOOTIMAGE_INCLUDE_DTB := true

# Init goes to init_boot (A13+). Generic ramdisk in boot.img, /init in init_boot.
BOARD_USES_INIT_BOOT_IMAGE := true
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608        # 8 MB
BOARD_USES_GENERIC_KERNEL_IMAGE := true

# vendor_dlkm holds loadable vendor modules (.ko files).
BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE := 67108864      # 64 MB starting
BOARD_VENDOR_DLKM_MODULES_LOAD := \
    $(shell cat $(DEVICE_PATH)/../../../../aether-rmx3171/modules/vendor_dlkm.modules.load 2>/dev/null | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')

# vendor_boot first-stage modules (must boot to /vendor mount).
BOARD_VENDOR_RAMDISK_FRAGMENTS := dlkm
BOARD_VENDOR_RAMDISK_FRAGMENT.dlkm.KERNEL_MODULE_DIRS := dlkm
BOARD_VENDOR_BOOT_MODULES_LOAD := \
    $(shell cat $(DEVICE_PATH)/../../../../aether-rmx3171/modules/vendor_boot.modules.load 2>/dev/null | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')

# ============================================================
# Kernel image — point to AETHER 6.6 tree
# ============================================================
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_SOURCE := kernel/realme/RMX3171-6.6
TARGET_KERNEL_CONFIG := mediatek-bazel_defconfig
TARGET_KERNEL_DEFCONFIG_OVERLAY := aether_rmx3171_overlay.config

# ============================================================
# A16 cmdline additions
# ============================================================
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=bootdevice
BOARD_KERNEL_CMDLINE += androidboot.selinux=enforcing
# init_boot is generic, so devicetree picks vendor cmdline via vendor_boot
BOARD_VENDOR_KERNEL_CMDLINE := buildvariant=user

# ============================================================
# AVB (A16) — vbmeta chains
# ============================================================
BOARD_AVB_VBMETA_VENDOR_BOOT := vendor_boot
BOARD_AVB_VBMETA_VENDOR_BOOT_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_VBMETA_VENDOR_BOOT_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 3

BOARD_AVB_INIT_BOOT_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_INIT_BOOT_ALGORITHM := SHA256_RSA2048
BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX_LOCATION := 4

BOARD_AVB_VBMETA_VENDOR_DLKM_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_VBMETA_VENDOR_DLKM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_DLKM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_DLKM_ROLLBACK_INDEX_LOCATION := 5

# ============================================================
# Super partition — add vendor_dlkm to the group
# ============================================================
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_PARTITION_LIST := product vendor system system_ext odm vendor_dlkm

# ============================================================
# VINTF — A16 manifest version
# ============================================================
PRODUCT_TARGET_VNDK_VERSION := 35
PRODUCT_SHIPPING_API_LEVEL := 35

# ============================================================
# system_dlkm partition — A16 GKI 2.0 (P0.2 fix)
# ============================================================
# GKI modules (mainline kernel drivers) live in /system_dlkm, vendor-specific
# in /vendor_dlkm. Split required for CTS-on-GSI compliance.
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE := 67108864     # 64 MB
BOARD_SYSTEM_DLKM_MODULES_LOAD := \
    $(shell cat $(DEVICE_PATH)/../../../../aether-rmx3171/modules/system_dlkm.modules.load 2>/dev/null | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')

# Add system_dlkm to AVB chain
BOARD_AVB_VBMETA_SYSTEM_DLKM := system_dlkm
BOARD_AVB_VBMETA_SYSTEM_DLKM_KEY_PATH := $(AETHER_AVB_KEY_PATH)
BOARD_AVB_VBMETA_SYSTEM_DLKM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_DLKM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_DLKM_ROLLBACK_INDEX_LOCATION := 6

# Add to super partition group
BOARD_MAIN_PARTITION_LIST += system_dlkm

# ============================================================
# bootconfig.img — A16 boot props (P0.4 fix)
# ============================================================
# Replaces kernel cmdline for `androidboot.*` props in A16+.
BOARD_BOOTCONFIG := \
    androidboot.hardware=mt6768 \
    androidboot.console=ttyS0,921600n8 \
    androidboot.boot_devices=bootdevice \
    androidboot.selinux=enforcing \
    androidboot.veritymode=enforcing \
    androidboot.gki.kernel_release_string=6.6.50-AETHER-X-RMX3171-A16+

# ============================================================
# DTBO image — A16 overlay device-tree (P0.1 fix)
# ============================================================
# Built by scripts/build/pack_dtbo.sh + flashed to dtbo partition.
BOARD_KERNEL_DTBOIMAGE_PARTITION_SIZE := 8388608       # 8 MB
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_INCLUDE_RECOVERY_DTBO := false                    # use main dtbo partition
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/../../../../out/dtbo.img

# ============================================================
# OTA + update_engine
# ============================================================
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_dlkm \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm
