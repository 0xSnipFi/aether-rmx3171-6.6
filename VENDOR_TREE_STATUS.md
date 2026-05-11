# RMX3171 Android 16 Vendor Tree Status

Created from local sources:

- A16 layout reference: `device_realme_RMX2020-sixteen-qpr1`
- RMX3171 stock properties/blobs: `narzo30A-stock/vendor_extracted`
- RMX3171 blob lists: `NARZO30A-_tree-main`
- RMX3171 old device tree: `device_realme_RMX3171-11`

## What Is Ready

- Android 16-style `device/realme/RMX3171` scaffold
- Android 16-style `vendor/realme/RMX3171` scaffold
- Stock-based `vendor.prop`
- A16 `fstab.mt6768` with `system`, `vendor`, `product`, `system_ext`, `odm`
- A16 VINTF files adapted from RMX2020 reference
- Blob staging script for stock RMX3171 `vendor_extracted`
- Proprietary file lists copied from Narzo 30A community tree
- Stock `vendor` and `odm` proprietary blobs staged from `narzo30A-stock/vendor_extracted`
- RMX3171 fingerprint, lights, shims, overlays, keylayout, audio, and sepolicy sources copied from the RMX3171 Android 11 tree
- Narzo 30A audio/media/seccomp/sensors/wifi configs copied from the community RMX3171 tree

## What Still Needs Device Testing

- Camera HAL and exact active sensor tuple
- Fingerprint HAL service and `/dev/goodix_fp` or Egis/Silead nodes
- WiFi/BT firmware handshake with the final 6.6 kernel
- Audio card name and MTK audio HAL compatibility
- Thermal zone names and Android 16 thermal HAL
- SELinux enforcing policy
- Vendor blob linker errors on Android 16

## Bring-Up Order

1. Place `device/realme/RMX3171` and `vendor/realme/RMX3171` into an Android 16 ROM source root.
2. Build userdebug permissive first.
3. Fix first-stage mount and VINTF failures.
4. Bring up display/touch/ADB.
5. Bring up WiFi/BT/sensors/audio/fingerprint.
6. Bring up camera and GPU stability.
7. Move SELinux toward enforcing.
