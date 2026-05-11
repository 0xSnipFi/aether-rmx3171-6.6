DEVICE_PATH := device/realme/RMX3171

$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)
$(call inherit-product-if-exists, vendor/realme/RMX3171/RMX3171-vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

PRODUCT_SHIPPING_API_LEVEL := 29
PRODUCT_EXTRA_VNDK_VERSIONS := 29
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
PRODUCT_SET_DEBUGFS_RESTRICTIONS := true
PRODUCT_ENABLE_UFFD_GC := true

TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1600

# Fingerprint feature declaration. Other stock feature XMLs come from
# proprietary/vendor/etc/permissions to avoid duplicate copy rules.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml

# Init and fstab.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768 \
    $(DEVICE_PATH)/init/fstab.mt6768:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6768 \
    $(DEVICE_PATH)/init/init.mt6768.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6768.rc \
    $(DEVICE_PATH)/init/init.mt6768.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6768.usb.rc \
    $(DEVICE_PATH)/init/init.connectivity.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.connectivity.rc \
    $(DEVICE_PATH)/init/init.modem.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.modem.rc \
    $(DEVICE_PATH)/init/init.sensor_1_0.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.sensor_1_0.rc \
    $(DEVICE_PATH)/init/ueventd.mtk.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc

# HAL packages expected in a Lineage/AOSP-MTK Android 16 tree.
PRODUCT_PACKAGES += \
    android.hardware.audio.service \
    android.hardware.bluetooth.audio-impl \
    android.hardware.drm-service.clearkey \
    android.hardware.gatekeeper@1.0-service \
    android.hardware.health@2.1-service \
    android.hardware.light@2.0-service.RMX3171 \
    android.hardware.memtrack-service.mediatek-mali \
    android.hardware.power-service.lineage-libperfmgr \
    android.hardware.thermal-service.mediatek \
    android.hardware.usb@1.3-service.basic \
    android.hardware.vibrator-service.mediatek \
    android.hardware.wifi-service \
    android.frameworks.sensorservice@1.0 \
    fastbootd \
    hostapd \
    wpa_supplicant

# RMX3171/OPLUS legacy service wrappers. These must be backed by copied ODM/vendor blobs.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.1-service.RMX3171 \
    ImsInit \
    libshim_showlogo

PRODUCT_PACKAGES += \
    libsensorndkbridge

# Properties.
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

# Runtime resource overlays can be added after first boot.
DEVICE_PACKAGE_OVERLAYS += \
    $(DEVICE_PATH)/overlay

PRODUCT_SOONG_NAMESPACES += \
    hardware/mediatek \
    hardware/mediatek/libmtkperf_client \
    $(DEVICE_PATH)
