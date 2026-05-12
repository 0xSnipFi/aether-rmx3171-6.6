# Porting guide — contribute a 4.14 → 6.6 driver port

This guide walks new contributors through landing a driver port. Most
gaps in [MISSING.md](MISSING.md) follow this same pattern.

## Prerequisites

- Working WSL2 / Ubuntu 22.04 with 250 GB free
- `clang-r510928` Android prebuilt (A055F-compatible)
- One physical Realme Narzo 30A (RMX3171) for testing
- USB-C UART adapter (recommended, see `BOOT_FAILURE_TRIAGE.md`)

## Setup

```bash
git clone https://github.com/<owner>/aether-rmx3171-6.6
cd aether-rmx3171-6.6

# Re-stage gitignored Samsung base + AnyKernel3
A055F_TARBALL=/path/to/SM-A055F_*.tar.gz \
    bash scripts/sync_samsung_base.sh
```

## Pick a driver

See `aether-rmx3171/ports/TODO/`. Each subdir has:
- `README.md` — porting strategy
- `source*/` — 4.14 source for reference

Easier first picks: panel, sia81xx, FM (out-of-tree).
Harder: gauge, fingerprint.
Hardest: Mali GPU, camera ISP, modem.

## Pattern

### 1. Read 4.14 source

```bash
# E.g. for sia81xx
less aether-rmx3171/ports/TODO/sia81xx-audio/source/sia81xx.c
```

Identify:
- Probe entry point
- Register map (chip datasheet)
- IOCTL ABI (preserve exact codes; vendor HAL depends)
- Init / power / suspend sequences

### 2. Find mainline template

Check `kernel-6.6/drivers/<subsys>/` and Samsung
`device-modules/drivers/<subsys>/` for a similar driver. Examples:
- Panel: `panel-wt-n28-xinxian-icnl9916c-hdp-vdo.c` (HDP DSI pattern)
- Charger: `mt6360_charger.c` (mainline mt6360)
- Touch: `goodix-berlin-i2c.c` (mainline goodix)
- ASoC codec: `max98357a.c` (simple I²S amp)

### 3. Write slim port

Drop from 4.14:
- proc_fs / debugfs dev-only nodes
- ESD protect work queues (handle in HAL)
- Factory self-test ioctls (HAL-only)
- Vendor IPC sockets / netlink unrelated to event delivery
- Telemetry / userspace shim layers

Keep:
- Probe + reset + power sequences (exact)
- Register read/write timing
- IRQ handler + event delivery
- IOCTL ABI numbers (vendor HAL byte-equivalent)
- DT bindings + GPIO/regulator/clk consumers

Target: 10–25 % of original LoC.

### 4. Add Kconfig + Makefile

```kconfig
config AETHER_FOO_RMX3171
    tristate "RMX3171 foo driver"
    depends on FOO_SUBSYS
    help
      ...
```

```makefile
obj-$(CONFIG_AETHER_FOO_RMX3171) += foo/foo-rmx3171.o
```

### 5. DT binding

Add node to `aether-rmx3171/dts/mt6768-rmx3171.dts`:
```dts
&i2c4 {
    rmx3171_foo: foo@1c {
        compatible = "vendor,foo-rmx3171";
        reg = <0x1c>;
        ...
        status = "okay";
    };
};
```

### 6. Module load

Add `.ko` filename to `aether-rmx3171/modules/vendor_dlkm.modules.load`.
If boot-critical: also add to `vendor_boot.modules.load` instead.

### 7. SELinux

If new `/dev` node:
- Add type to `device/realme/RMX3171/sepolicy/private/aether_ports.te`
- Add path to `file_contexts`
- Add allow rules for relevant HAL

### 8. Build + test

```bash
bash aether-rmx3171/build/build_aether_6_6.sh
# AnyKernel zip lands in releases/
```

Flash, capture `dmesg | grep <driver>`. Iterate.

### 9. PR

Branch + PR with:
- Title: `port: <driver> from 4.14 to 6.6`
- Body covers: source, strategy, what dropped, test status (device-tested
  or compile-only), LoC saved
- Link to MISSING.md item

## 4.14 → 6.6 API cheat sheet

| 4.14 | 6.6 |
|---|---|
| `proc_create(name, mode, parent, &fops)` | `proc_create(name, mode, parent, &proc_ops)` (struct proc_ops) |
| `access_ok(VERIFY_*, p, n)` | `access_ok(p, n)` |
| `getnstimeofday64(&ts)` | `ktime_get_real_ts64(&ts)` |
| `do_gettimeofday(&tv)` | `ktime_get_real_ts64(&ts)` |
| `current_kernel_time()` | `ktime_get_coarse_real_ts64` |
| `wait_queue_t` | `wait_queue_entry_t` |
| `wait.task_list` | `wait.entry` |
| `wake_lock_init/destroy` | `wakeup_source_register/unregister` |
| `wake_lock_timeout` | `__pm_wakeup_event` |
| `get_user_pages(tsk, mm, …)` | `get_user_pages(…)` (no tsk/mm) |
| `kernel_read(file, off, buf, n)` | `kernel_read(file, buf, n, &off)` |
| `THIS_MODULE->refcnt` | `try_module_get` / `module_put` |
| `kthread_run(fn, data, name)` | same |
| `signal_pending(current)` | same |
| `request_firmware_nowait(THIS_MODULE, ...)` | same with new signature |
| `class_create(THIS_MODULE, name)` | `class_create(name)` (6.4+) |
| `pcim_iomap_regions` | `pcim_iomap_region` (single) or `pcim_iomap_table` |
| `mt-plat/mtk_*` | not in mainline — replace with mainline equivalents or stub |
| `mach/mt_*` | 4.14-only — drop or replace |
| `mtk_clk_set_parent` | `clk_set_parent` |
| `dma_buf_get + kmap` | `dma_buf_vmap` |

## Common pitfalls

1. **Vendor IOCTL ABI** — vendor HAL `vendor/lib*/hw/*.so` speaks exact
   ioctl numbers. Renumbering = silent breakage in app layer.
2. **Reset GPIO polarity** — 4.14 often uses active-high in code with
   active-low DTS; verify both.
3. **MTK clock framework gone** — `clk-mt6768.c` 3365 LoC driver doesn't
   exist in mainline. Use bootloader-configured clocks + DTS
   `fixed-clock` workaround.
4. **MTK SCP firmware required** — sensor hub etc. need
   `firmware/scp.img` from stock vendor; not redistributed.
5. **Samsung A055F base != RMX3171** — both are MT6768 but Samsung
   tree has `drivers/samsung/` Exynos quirks that don't apply. Skip
   those when porting.

## Reviewers' rubric

Maintainers will check:
- [ ] Original 4.14 attribution preserved in header comment
- [ ] LoC <= 30 % of original (else justify in PR)
- [ ] No `#include <mt-plat/...>` or `<mach/...>` remaining
- [ ] DT binding documented in `mt6768-rmx3171.dts`
- [ ] Module load list updated
- [ ] Module compiles clean against kernel-6.6 base
- [ ] SELinux contexts present for any new /dev node
- [ ] At least compile-test posted; device-test preferred

## Help

- GitHub Discussions for design questions
- `boot_failure` issue template for crashes
- `port_request` issue template to claim a TODO/ item

Happy porting.
