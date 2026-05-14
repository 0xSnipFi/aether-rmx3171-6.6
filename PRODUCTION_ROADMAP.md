# AETHER RMX3171 Production Roadmap

The canonical roadmap lives at:

- `docs/PRODUCTION_ROADMAP.md`

This root file exists so GitHub users can find the production plan quickly.

Current real-device rule:

- RMX3171 stock hardware uses boot-header-v2, non-A/B, physical boot + dtbo.
- Do not make physical `vendor_boot` / `init_boot` the default target.
- Linux 6.6 Android 16 bring-up should use stock boot flow plus logical
  `vendor_dlkm` / `system_dlkm` inside custom super for full ROM builds.
- Physical PGPT remap is research-only until a tested LK/preloader path proves
  that the bootloader actually consumes new partitions.

