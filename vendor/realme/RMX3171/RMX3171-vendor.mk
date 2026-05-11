RMX3171_VENDOR_PATH := vendor/realme/RMX3171

PRODUCT_SOONG_NAMESPACES += \
    $(RMX3171_VENDOR_PATH)

# Full stock blob staging. Run tools/stage_proprietary.ps1 before building.
# Copy explicit partitions/directories only. Stock root build.prop/default.prop are
# intentionally not copied because Android generates partition build props.
PRODUCT_COPY_FILES += \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/app),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/app,$(TARGET_COPY_OUT_VENDOR)/app)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/bin),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/bin,$(TARGET_COPY_OUT_VENDOR)/bin)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/etc),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/etc,$(TARGET_COPY_OUT_VENDOR)/etc)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/firmware),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/firmware,$(TARGET_COPY_OUT_VENDOR)/firmware)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/lib),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/lib,$(TARGET_COPY_OUT_VENDOR)/lib)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/lib64),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/lib64,$(TARGET_COPY_OUT_VENDOR)/lib64)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/overlay),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/overlay,$(TARGET_COPY_OUT_VENDOR)/overlay)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/vendor/res),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/vendor/res,$(TARGET_COPY_OUT_VENDOR)/res)) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/odm),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/odm,$(TARGET_COPY_OUT_ODM))) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/product),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/product,$(TARGET_COPY_OUT_PRODUCT))) \
    $(if $(wildcard $(RMX3171_VENDOR_PATH)/proprietary/system_ext),$(call find-copy-subdir-files,*,$(RMX3171_VENDOR_PATH)/proprietary/system_ext,$(TARGET_COPY_OUT_SYSTEM_EXT)))

# Stock APKs and services are copied from proprietary/vendor and proprietary/odm.
# Keep generated module definitions separate if a ROM tree later converts any blob
# to Android.bp prebuilt modules.
