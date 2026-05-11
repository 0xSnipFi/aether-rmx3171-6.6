$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/realme/RMX3171/device.mk)

PRODUCT_NAME := aether_RMX3171
PRODUCT_DEVICE := RMX3171
PRODUCT_BRAND := realme
PRODUCT_MODEL := realme narzo 30A
PRODUCT_MANUFACTURER := realme

PRODUCT_GMS_CLIENTID_BASE := android-realme

BUILD_FINGERPRINT := alps/vnd_oppo6769/oppo6769:11/RP1A.200720.011/1623809323039:user/release-keys
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="vnd_oppo6769-user 11 RP1A.200720.011 1623809323039 release-keys" \
    BuildFingerprint=$(BUILD_FINGERPRINT) \
    DeviceName=RMX3171 \
    DeviceProduct=RMX3171 \
    SystemDevice=RMX3171 \
    SystemName=RMX3171
