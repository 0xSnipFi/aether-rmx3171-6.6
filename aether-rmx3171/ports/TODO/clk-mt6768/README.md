# clk-mt6768 — MT6768 clock subsystem

## What this is

4.14 Realme/OPPO clock driver for MT6768. 3365-line C + clkmgr + power-gate.
Uses MTK-internal frameworks: `clkmgr`, `clkchk`, `clkdbg`, `mtcmos`.

## Why we skip full port

- ~6500 LoC across 5 files.
- Depends on `<mt-plat/mtk_devinfo.h>`, `<mt-plat/upmu_common.h>` — not in mainline.
- `mtk_clkmgr` framework superseded by upstream `clk/mediatek/` infra in 6.6.
- Mainline `clk-mt8186.c` / `clk-mt8192.c` (same arch family) is the right shape but **MT6768 has no upstream driver**.
- Blind port = boot hang on clock-gate mistakes. Without scope/JTAG = unrecoverable.

## Recommended strategy: DTS fixed-clocks

Bootloader (LK / preloader) already configures MUXes + PLLs to OS-ready state.
Use `fixed-clock` DT nodes for the rates the driver tree needs:

```dts
clk26m: clk26m {
    compatible = "fixed-clock";
    #clock-cells = <0>;
    clock-frequency = <26000000>;
    clock-output-names = "clk26m";
};

clk13m: clk13m {
    compatible = "fixed-factor-clock";
    #clock-cells = <0>;
    clocks = <&clk26m>;
    clock-mult = <1>;
    clock-div = <2>;
    clock-output-names = "clk13m";
};

/* repeat for every leaf clock IP consumers (mmc, usb, i2c, spi, uart) need */
```

Extract clock list from `mt6768-clk.h` (staged here as `mt6768-clk.h`).
Cross-reference rates from stock A11 boot.

## Alternative: skeleton mainline-style driver

If full port wanted later:

1. Reference `drivers/clk/mediatek/clk-mt8186-topckgen-and-infracfg.c`.
2. Define `clk_branch` / `clk_mux` arrays from MT6768 register map.
3. Use `mtk_clk_register_*` helpers (already in 6.6).
4. Register count: ~600 clocks → ~3000 lines of tables (no logic).

Plan ~80 hours engineering + device boot test.

## Files staged

| File | What | LoC |
|---|---|---:|
| `clk-mt6768.c` | top clock controller | ~3365 |
| `clk-mt6768-pg.c` | power-gate (mtcmos) | ~1200 |
| `clk-mt6768-pg.h` | pg defines | ~400 |
| `mt6768_clkmgr.c` | legacy clkmgr API | ~800 |
| `mt6768_clkmgr.h` | clkmgr defines | ~600 |
| `mt6768-clk.h` | dt-bindings (use this in DTS) | ~300 |

## Acceptance

- `mmc0` enumerates eMMC at 200 MHz HS400 (or 50 MHz fallback).
- `mtu3` USB host enumerates.
- No clock-related WARN/BUG in dmesg.

## Status: deferred. P3.
