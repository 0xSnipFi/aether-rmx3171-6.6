#!/usr/bin/env bash
# AETHER RMX3171 — extract KMI allowlist from built vmlinux.
#
# Usage: scripts/build/extract_kmi.sh [vmlinux-path]
#
# Produces aether-rmx3171/abi/abi_gki_aarch64_aether — one symbol per line.
# A16 GKI 2.0 requires this to allow vendor_dlkm modules to bind.
#
# Run after a stable kernel build. Symbol list is then committed to repo.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VMLINUX="${1:-$REPO_ROOT/out/vmlinux}"
OUT="$REPO_ROOT/aether-rmx3171/abi/abi_gki_aarch64_aether"

if [ ! -f "$VMLINUX" ]; then
    echo "ERROR: vmlinux not found at $VMLINUX"
    echo "Build first: bash aether-rmx3171/build/build_aether_6_6.sh"
    exit 1
fi

NM="${LLVM_NM:-llvm-nm}"
if ! command -v "$NM" >/dev/null; then
    NM=nm
fi

echo "[1/3] extract __ksymtab_* symbols from $VMLINUX"
"$NM" --defined-only "$VMLINUX" \
    | awk '$3 ~ /^__ksymtab_/ { sub(/^__ksymtab_/, "", $3); print $3 }' \
    | sort -u \
    > "$OUT.raw"

echo "[2/3] filter trusted prefixes only"
# Keep MTK + mainline subsystem symbols vendor modules need
grep -E '^(mtk_|mt6358|mt6370|mt6360|mt6768|drm_|mipi_dsi_|regulator_|gpiod_|clk_|i2c_|spi_|input_|power_supply_|thermal_zone_|regmap_|snd_soc_|pinctrl_|of_|platform_|module_|kthread_|wait_|complete_|mutex_|spin_|init_)' \
    "$OUT.raw" > "$OUT"

cat >> "$OUT" <<'EXTRA'
# Additional symbols required by AETHER ported drivers:
mipi_dsi_dcs_write_buffer
mipi_dsi_dcs_set_display_off
mipi_dsi_dcs_enter_sleep_mode
drm_panel_init
drm_panel_add
drm_panel_remove
drm_panel_of_backlight
input_mt_init_slots
input_mt_slot
input_mt_report_slot_state
input_mt_report_slot_inactive
input_mt_sync_frame
netlink_kernel_create
netlink_kernel_release
netlink_unicast
nlmsg_new
nlmsg_put
cdev_init
cdev_add
cdev_del
class_create
class_destroy
device_create
device_destroy
EXTRA

sort -u -o "$OUT" "$OUT"
SYMS=$(wc -l < "$OUT")

echo "[3/3] $SYMS symbols → $OUT"
rm -f "$OUT.raw"
echo
echo "[+] Commit with:"
echo "    git add aether-rmx3171/abi/abi_gki_aarch64_aether"
echo "    git commit -m 'abi: lock KMI allowlist (${SYMS} symbols)'"
