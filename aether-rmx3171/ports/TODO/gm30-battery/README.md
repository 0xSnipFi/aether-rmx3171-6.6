# gm30 fuelgauge — MT6359/MT6358 coulomb counter

## What this is

MTK Gauge Generation 3 (`gm30`) battery fuelgauge. Tracks SOC by integrating
coulombs from PMIC's onboard ADC + voltage curves from `rmx3171_bat_profile.dtsi`.

## Why this is hard to port

15000+ LoC framework. Tight coupling to MTK power-supply layer:
- `<mtk_battery.h>` ↔ `<mtk_charger.h>` ↔ `<mtk_pe.h>` (all 4.14-only).
- Uses `power_supply` class but extends with vendor-private `BAT_PROP_*` ioctls.
- Battery thread (`battery_kthread`) polls every 60s — reentrancy issues
  on 6.6 PREEMPT_RT.

## Strategy: defer + use mt6370_charger

`mt6370_charger.ko` already builds (in v4). It reports:
- `POWER_SUPPLY_PROP_VOLTAGE_NOW` — accurate.
- `POWER_SUPPLY_PROP_CURRENT_NOW` — accurate.
- `POWER_SUPPLY_PROP_CAPACITY` — **approximate** (linear V→% mapping).

For experimental kernel this is enough. SOC accuracy ±10%, not battery-fade
trackable. Daily-driver path = needs gm30.

## If you want to port

**Path A**: port the gm30 *only* (drop pe/pdc/loop_charger MTK extras).
~3000 LoC. Hook into mt6370_charger as power-supply provider.

**Path B**: write a tiny "voltage-curve fuelgauge" using
`rmx3171_bat_profile.dtsi` data directly:

```c
// drivers/power/supply/aether_simple_gauge.c
// 4 batteries × 5 temps × 100 SOC points already in DTS.
// Read VBAT from mt6370, interp temperature from thermal zone,
// table lookup → SOC.
// 400 LoC, no MTK framework dep.
```

Path B is realistic. Accuracy: ±3% SOC, no learning, no battery health.
Acceptable for non-mission-critical phone.

## Files staged (reference only)

| File | What | LoC |
|---|---|---:|
| `mtk_battery.c` | top driver | ~5000 |
| `mtk_battery_core.c` | gauge math | ~4000 |
| `mtk_battery_internal.h` | private API | ~1500 |
| `mtk_gauge_class.{c,h}` | gauge_dev abstraction | ~600 |
| `mtk_gauge_coulomb_service.c` | coulomb integration | ~1000 |
| `mtk_gauge_time_service.{c,h}` | timekeeping | ~500 |

## Acceptance

- `cat /sys/class/power_supply/battery/capacity` reports plausible %.
- `dumpsys battery` agrees within ±5% of measured Vbat.

## Status: P3, deferred. Charger reports approx SOC.
