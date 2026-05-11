## Summary

(One-line description of what this PR does.)

## Type

- [ ] DTS / pinctrl extraction
- [ ] Config overlay (kernel option)
- [ ] Vendor tree (BoardConfig, fstab, sepolicy, VINTF)
- [ ] Build script / CI
- [ ] Documentation
- [ ] KernelSU / NetHunter / Magisk integration
- [ ] Other:

## Evidence

(For hardware-touching changes, point to evidence:
 - stock dtbdump line number
 - getprop output
 - vendor blob string
 - upstream Linux 6.6 driver source
 - Samsung A055F driver source)

```
[paste evidence]
```

## Build verification

- [ ] `bash aether-rmx3171/build/build_aether_6_6.sh` passes
- [ ] DTC parses `mediatek/mt6768-rmx3171.dtb`
- [ ] No new NTFS case-collision-prone filenames
- [ ] No proprietary blobs committed

## Device test (optional)

- [ ] Flashed on RMX3171 hardware
- [ ] Boot result: (success / fail / partial)
- [ ] dmesg attached:

```
[paste relevant dmesg]
```

## Notes

(Anything maintainer/reviewer should know.)
