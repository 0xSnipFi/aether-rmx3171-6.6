# Port-TODO scaffolds — Linux 6.6 ACK

4.14 source staged + port playbooks. Each subdir = self-contained task.
Pick one, follow `README.md`, port, send PR.

## State

| Driver | 4.14 LoC | Strategy | Risk | Priority |
|---|---:|---|---|---|
| `clk-mt6768/` | ~6500 (C+H) | **Skip full port** → DTS fixed-clocks + bootloader-init | Low | P3 |
| `sia81xx-audio/` | ~3500 | **Rewrite minimal ASoC codec** (drop 4.14 AFE coupling) | Med | P2 |
| `panel-ilt9881h/` | ~600 each | **Translate DSI init seq → DRM `mipi_dsi_dcs_write`** | Med | P1 |
| `gm30-battery/` | ~15000 | **Defer** → MT6370 PMIC supplies basic SOC | Low | P3 |
| `fm-mt6631/` | ~30000 | **Out-of-tree module** (4.14 source already self-contained) | Low | P2 |
| `goodix-fingerprint/` | ~2500 | **Char dev + SPI** port (no DRM/PMIC coupling) | Low | P2 |
| `connsys-mt6768-wifi/` | n/a | **DONE in aetherx** — see REFERENCE.txt | - | P0 done |

P1 = visible (panel = no boot screen → no daily use).
P2 = useful (radio/audio amp/fp = quality of life).
P3 = optional (clk = bootloader handles; battery = approx works).

## Common porting rules

1. Read `source*/` first. Note every kernel header `#include`.
2. For each header missing in 6.6, find replacement:
   - `<mt-plat/...>` → not in mainline. Use generic kernel header or stub.
   - `<mach/mt_...>` → 4.14-only. Replace with mainline equivalent.
   - `mtk_clk_set_parent` etc → use `clk_set_parent` (generic CCF).
3. 4.14 → 6.6 API cheatsheet:
   | 4.14 | 6.6 |
   |---|---|
   | `proc_create(..., &fops)` | `proc_create(..., &proc_ops)` (struct proc_ops, not file_ops) |
   | `access_ok(VERIFY_*, p, n)` | `access_ok(p, n)` |
   | `ktime_get_ns()` | same |
   | `getnstimeofday64` | `ktime_get_real_ts64` |
   | `get_user_pages(tsk, mm, ...)` | `get_user_pages(...)` (no tsk/mm) |
   | `kernel_read(file, off, buf, n)` | `kernel_read(file, buf, n, &off)` |
   | `current_kernel_time()` | `ktime_get_coarse_real_ts64` |
   | `do_gettimeofday(&tv)` | `ktime_get_real_ts64` |
   | `wait.task_list` | `wait.entry` |
   | direct `THIS_MODULE->refcnt` | `try_module_get` / `module_put` |
4. Keep ports as **loadable .ko** when possible (faster iteration, no kernel rebuild).
5. Match upstream style: `checkpatch.pl --strict` before PR.

## Where ports land in repo

- `.c/.h` → drop into `kernel-6.6/drivers/<subsys>/mediatek/` (or `<subsys>/realme/`)
- Kconfig entry → add to that dir's `Kconfig`
- Makefile → `obj-$(CONFIG_FOO) += foo.o`
- DTS node → `aether-rmx3171/dts/mt6768-rmx3171.dts`
- Module load list → `aether-rmx3171/modules/vendor_dlkm.modules.load`
- Config enable → `aether-rmx3171/configs/aether_rmx3171_overlay.config`

## Test path

No device → community test only. Boot test required before claiming "works".
Submit boot log via GH issue `boot_failure` or `hardware_broken` templates.
