# goodix-fingerprint — GF3208/9518 optical FP sensor

## What this is

Goodix in-display / capacitive fingerprint sensor on SPI bus. RMX3171 has
**Goodix optical** (GF_3208 family, per 4.14 staged source).

Kernel side = char device + SPI driver + IRQ handler. Real matching happens in
userspace TEE blob (vendor `goodix.fingerprint@2.1-service`).

## Strategy: char dev port, simple

4.14 driver `goodix_optical_fp/` is small (~2500 LoC). No DRM, no PMIC, no
ASoC coupling. Just SPI + GPIO + IRQ + netlink → char dev.

## Steps

1. Land sources in `kernel-6.6/drivers/misc/aether/goodix_fp/`.
2. Kill 4.14-only headers:
   - `<mt-plat/mtk_spi.h>` → use generic `<linux/spi/spi.h>`.
   - `mt_spi_enable_master_clk()` → drop; mainline SPI core handles clk.
   - `mt_pinctrl_set` → use `pinctrl_select_state` (already in 6.6).
3. Netlink: 4.14 uses NLMSG_DONE flow. 6.6 same — just verify
   `netlink_kernel_create` signature unchanged (it is).
4. Wakelock API:
   ```c
   // 4.14:
   wake_lock_init(&fp->wake_lock, WAKE_LOCK_SUSPEND, "fp_wakelock");
   wake_lock_timeout(&fp->wake_lock, msecs_to_jiffies(2000));

   // 6.6:
   fp->ws = wakeup_source_register(&pdev->dev, "fp_wakelock");
   __pm_wakeup_event(fp->ws, 2000);
   ```
5. IRQ handler: `request_threaded_irq` API unchanged; just verify
   `IRQF_TRIGGER_RISING` matches your sensor (4.14 vendor sets RISING).
6. Build as `goodix_fp.ko` module. Auto-load via `vendor_dlkm.modules.load`.

## DT binding

```dts
&spi1 {
    fingerprint@0 {
        compatible = "goodix,gf3208";
        reg = <0>;
        spi-max-frequency = <8000000>;
        fp-gpio-reset = <&pio 156 GPIO_ACTIVE_LOW>;
        fp-gpio-irq = <&pio 1 GPIO_ACTIVE_HIGH>;
        interrupt-parent = <&pio>;
        interrupts = <1 IRQ_TYPE_EDGE_RISING>;
    };
};
```

## Files staged

| File | What |
|---|---|
| `gf_spi.{c,h}` | char dev + SPI ops |
| `gf_spi_tee.{c,h}` | TEE-bridge IOCTL ABI (preserve ABI verbatim — vendor HAL depends on it) |
| `gf_platform.c` | platform glue |
| `gf_platform_mtk.c` | MTK-specific GPIO/SPI bring-up |
| `gf_netlink.c` | sensor → userspace event channel |

## Critical: preserve IOCTL ABI

`gf_spi.h` defines `GF_IOC_*`. **Do not renumber.** Vendor blob (`gxfpchip.so`,
`goodix.fingerprint@2.1-service`) speaks these exact codes. Mismatch =
silently broken enrollment.

## Acceptance

- `lsmod | grep goodix_fp`.
- `/dev/goodix_fp` exists, mode 660 root:system.
- `getprop ro.boot.fingerprint` reports goodix.
- enrollment + match through SetupWizard works (requires matching vendor HAL).

## Status: P2, deferred. Driver can land before HAL — kernel side independent.
