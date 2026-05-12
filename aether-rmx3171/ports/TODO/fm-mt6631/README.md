# fm-mt6631 — FM radio (MT6631 combo chip)

## What this is

MTK combo Connsys chip = WiFi+BT+FM+GPS. We already port WiFi (gen4m) + BT
(btmtk*) for 6.6. FM is the leftover.

4.14 source = `kernel_modules/connectivity/fmradio/` — **already structured as
out-of-tree module**. Good news: 95% of the port pattern is "make it build
against 6.6 headers".

## Strategy: out-of-tree module

Don't touch `kernel-6.6/drivers/`. Build standalone, install as
`fmradio.ko` into `vendor_dlkm`.

## Steps

1. Copy `fm-mt6631/source/` → `aether-rmx3171/external-modules/fmradio/`.
2. Audit `inc/fm_*.h` for 4.14-only kernel headers:
   ```
   grep -rEn '<mt-plat|<mach/|<mt6631_fm' inc/
   ```
3. Replace each:
   - `<mt-plat/aee.h>` → drop (no panic-on-FM-fail).
   - `<mach/mt_boot.h>` → drop / stub `get_boot_mode()` = NORMAL_BOOT.
   - `mtk_wcn_consys_*` → already exists in 6.6 if `MTK_COMBO_CHIP_CONSYS` set.
4. Switch `proc_create(name, mode, parent, &fops)` to `proc_ops`:
   ```c
   static const struct proc_ops fm_proc_ops = {
       .proc_open = fm_proc_open,
       .proc_read = seq_read,
       .proc_lseek = seq_lseek,
       .proc_release = single_release,
   };
   ```
5. Rebuild as OOT module:
   ```Makefile
   obj-m += fmradio.o
   fmradio-y := core/fm_main.o core/fm_cmd.o core/fm_patch.o ...
   ccflags-y += -I$(M)/inc -I$(M)/core -I$(M)/plat/inc
   ```
6. Module load: add `fmradio.ko` to `vendor_dlkm.modules.load`.

## Known 4.14→6.6 issues for FM stack

| Symptom | Fix |
|---|---|
| `proc_create_data` 5-arg vs 4-arg | use `proc_create_seq_data` for read-only nodes |
| `timer_setup_on_stack` | now `timer_setup`, init_timer gone |
| `wait_queue_t` → `wait_queue_entry_t` | rename throughout |
| `signal_pending(current)` still ok | no change |
| `kernel_sigaction` API differs | likely unused by FM |

## Userspace

Stock Realme FM app talks `/dev/fm` ioctl. The 4.14 ioctl ABI (`fm_ioctl.h`) is
unchanged in this port. Stock app works once driver loads.

## Acceptance

- `lsmod | grep fmradio` shows loaded.
- `cat /proc/fm` returns chip info.
- FM app scans + plays stations.

## Status: P2, deferred. Self-contained — port is feasible without device test
(safe to flash since module load failure won't brick).
