---
name: Port request
about: Claim a 4.14 → 6.6 driver port from ports/TODO/
title: "port: <driver> from 4.14 to 6.6"
labels: ["port", "help wanted"]
assignees: ""
---

## What driver

Pick one from `aether-rmx3171/ports/TODO/`:

- [ ] clk-mt6768 — P3, DTS fixed-clock fallback
- [ ] panel-ilt9881h — ✅ already landed (panel-ilt9881h-rmx3171.c)
- [ ] sia81xx-audio — ✅ already landed (sia81xx-aether.c)
- [ ] gm30-battery — ✅ already landed (aether-simple-gauge.c)
- [ ] fm-mt6631 — ✅ already landed (fm-mt6631-aether.c)
- [ ] goodix-fingerprint — ✅ already landed (goodix-fp-rmx3171.c)
- [ ] connsys-mt6768-wifi — ✅ done in aetherx tree
- [ ] **Other:** _________

## Why

What does this driver unblock? (camera preview? GPU 3D? cellular?)

## My plan

Source path I'll port from:
```
aether-rmx3171/ports/TODO/<dir>/source/...
```

Mainline template I'll model after:
```
kernel-6.6/drivers/<subsys>/<file>.c
```

Estimated LoC after slimming: ~____

## Test status I'll commit

- [ ] Compile-only (build green on CI)
- [ ] Device boot test (UART log attached)
- [ ] Functional smoke test (subsystem reports working)

## Timeline

Expect to PR in _____ weeks.

## Read first

- `docs/PORTING.md` — the porting playbook
- `docs/PRODUCTION_ROADMAP.md` — where this fits in phase plan
- `aether-rmx3171/ports/TODO/<dir>/README.md` — driver-specific strategy
