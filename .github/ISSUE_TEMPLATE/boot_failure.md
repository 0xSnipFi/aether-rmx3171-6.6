---
name: Device boot failure
about: Kernel flashed but device does not boot
title: '[BOOT] '
labels: bug, boot-failure
assignees: ''
---

## Device

- Model: RMX3171 / RMX3171L1 / other
- Region: e.g. India, Indonesia
- Stock ROM version (before flashing): e.g. RMX3171_11_A.17
- Bootloader unlocked: yes / no
- A/B partitions: yes / no

## AETHER build

- Tag or commit: e.g. `v0.1.0-experimental` or `commit abc123`
- Zip filename + sha256:
  ```
  AETHER_X_RMX3171_6.6_A16-YYYYMMDD.zip
  sha256: ...
  ```

## Build environment

- Linux distro: e.g. Ubuntu 22.04 WSL
- clang version: `clang --version`
- Built from Samsung A055F base: yes / no (which version)
- Full Kleaf build: yes / no

## Symptom

- [ ] Stuck at fastboot screen
- [ ] Stuck at boot logo
- [ ] Bootloop (loops every N seconds)
- [ ] Stuck at recovery
- [ ] Stuck at "Decryption unsuccessful"
- [ ] Boots but no display
- [ ] Boots but no touch
- [ ] Other (describe)

## dmesg / boot log

Paste UART output, recovery shell dmesg, or last_kmsg. Use code blocks.

```
[ paste here ]
```

## Steps to reproduce

1.
2.
3.

## What you've tried

- [ ] Flashed back to stock and re-flashed
- [ ] Cleared cache + dalvik
- [ ] Tried different recovery
- [ ] Other (describe)

## Stock recovery backup available

- [ ] Yes — I can revert if needed
- [ ] No

> **Note:** Maintainers can only iterate on DTS/config when given dmesg
> output. If you cannot get any log, please at least confirm whether the
> Image.gz-dtb sha256 matches a known release.
