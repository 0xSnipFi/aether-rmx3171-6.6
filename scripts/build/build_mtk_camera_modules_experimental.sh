#!/usr/bin/env bash
# Build the compile-proven MTK ISP3 provider + RMX3171 imgsensor chain.
#
# This is intentionally experimental. It builds real staged MediaTek sources
# that are needed before the RMX3171 camera stack can be device-tested:
#   SMI core/debug -> IOMMU debug -> IRQ debug -> CMDQ -> MDP helper -> ISP3
#   ISP3_M imgsensor bridge -> OV13B10 + S5K4H7 + W2GC02 RMX3171 sensors
#
# The staged device-modules tree is gitignored, so the RMX3171-specific
# 4.14/ISP3 -> 6.6 source fixes live as tracked patch files under
# aether-rmx3171/ports/patches/imgsensor/. This script applies them
# idempotently before building. Keep this path opt-in until camera is proven
# with physical boot logs and camera HAL logs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
K="${REPO_ROOT}/kernel-6.6"
OUT="${REPO_ROOT}/out"
DM="${REPO_ROOT}/device-modules"
IMGSENSOR_PATCH_DIR="${REPO_ROOT}/aether-rmx3171/ports/patches/imgsensor"

CC="${CC:-clang}"
LD="${LD:-ld.lld}"
AR="${AR:-llvm-ar}"
NM="${NM:-llvm-nm}"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CROSS32="${CROSS_COMPILE_COMPAT:-arm-linux-gnueabi-}"

COMMON_MAKE=(
    -C "$K"
    O="$OUT"
    ARCH=arm64
    CC="$CC"
    LD="$LD"
    AR="$AR"
    NM="$NM"
    OBJCOPY="$OBJCOPY"
    CROSS_COMPILE="$CROSS"
    CROSS_COMPILE_COMPAT="$CROSS32"
)

WARN_FLAGS=(
    -Wno-error=return-type
    -Wno-error=implicit-function-declaration
    -Wno-error=incompatible-pointer-types
)

MTK_HEADER_FLAGS=(
    -I"$DM/include"
    -I"$DM/include/soc/mediatek"
    -I"$DM/drivers/misc/mediatek/mmp"
    -include "$DM/include/dt-bindings/memory/mtk-memory-port.h"
    -include "$DM/include/soc/mediatek/smi.h"
    -include "$DM/drivers/misc/mediatek/mmp/mmprofile.h"
)

join_flags() {
    local IFS=" "
    echo "$*"
}

build_one() {
    local label="$1"
    shift
    echo
    echo "[camera-exp] $label"
    make "${COMMON_MAKE[@]}" "$@"
}

require_file() {
    local path="$1"
    if [ ! -f "$path" ]; then
        echo "FAIL: expected file not produced: $path" >&2
        exit 1
    fi
}

apply_patch_idempotent() {
    local patch="$1"

    if git -C "$REPO_ROOT" apply --check --recount "$patch" >/dev/null 2>&1; then
        echo "[camera-exp] applying $(basename "$patch")"
        git -C "$REPO_ROOT" apply --recount "$patch"
        return
    fi

    if git -C "$REPO_ROOT" apply --reverse --check --recount "$patch" >/dev/null 2>&1; then
        echo "[camera-exp] already applied $(basename "$patch")"
        return
    fi

    echo "[camera-exp] patch context already folded or drifted: $(basename "$patch")"
}

validate_imgsensor_source_fixes() {
    local makefile="$DM/drivers/misc/mediatek/imgsensor/src/isp3_m/Makefile"
    local kd_header="$DM/drivers/misc/mediatek/imgsensor/inc/kd_imgsensor.h"
    local seninf_cfg="$DM/drivers/misc/mediatek/imgsensor/src/isp3_m/seninf/seninf_cfg.h"
    local sensor_list="$DM/drivers/misc/mediatek/imgsensor/src/common/v1_1/imgsensor_sensor_list.c"
    local seninf_clk="$DM/drivers/misc/mediatek/imgsensor/src/common/v1_1/seninf_clk.c"
    local imgsensor_c="$DM/drivers/misc/mediatek/imgsensor/src/common/v1_1/imgsensor.c"

    grep -Fq '../common/$(COMMON_VERSION)/camera_hw' "$makefile"
    grep -Fq '../inc' "$makefile"
    grep -Fq 'drivers/misc/mediatek/include' "$makefile"
    grep -Fq 'DFS_CTRL_BY_OPP' "$makefile"
    grep -Fq 'cam_cal/inc' "$makefile"
    grep -Fq 'OTP_PORTING=0' "$makefile"
    grep -Fq 'ov13b10main_mipi_raw' "$makefile"
    grep -Fq 'OV13B10MAIN_SENSOR_ID' "$kd_header"
    grep -Fq 'OV13B10MAIN_MIPI_RAW_SensorInit' "$sensor_list"
    grep -Fq 'W2GC02M1MICROCXT_MIPI_RAW_SensorInit' "$sensor_list"
    grep -Fq 'NO_CLK_METER' "$seninf_clk"
    grep -Fq 'kal_uint32 main_sensor_id = 0xffffffff;' "$imgsensor_c"
    require_file "$seninf_cfg"
    require_file "$DM/drivers/misc/mediatek/imgsensor/src/common/v1_1/camera_hw/Makefile"
}

apply_imgsensor_patchset() {
    local patches=(
        aether_imgsensor_include_order_probe_20260513.patch
        aether_imgsensor_header_path_probe_20260513.patch
        aether_imgsensor_mtk_include_probe_20260513.patch
        aether_imgsensor_use_v1_1_camera_hw_probe_20260513.patch
        aether_imgsensor_v1_1_seninf_probe_20260513_v2.patch
        aether_imgsensor_rmx3171_sensor_aliases_probe_20260513.patch
        aether_imgsensor_v1_1_dfs_flag_probe_20260513.patch
        aether_imgsensor_no_clk_meter_probe_20260513.patch
        aether_imgsensor_rmx3171_sensor_objects_top_makefile_20260513.patch
        aether_imgsensor_cam_cal_include_probe_20260513.patch
        aether_imgsensor_w2gc02_otp_optional_probe_20260513_v2.patch
        aether_imgsensor_main_sensor_id_guard_probe_20260513.patch
    )

    for patch in "${patches[@]}"; do
        require_file "$IMGSENSOR_PATCH_DIR/$patch"
        apply_patch_idempotent "$IMGSENSOR_PATCH_DIR/$patch"
    done

    validate_imgsensor_source_fixes
}

mkdir -p "$OUT"

apply_imgsensor_patchset

SMI_CORE_SYMS="$DM/drivers/memory/Module.symvers"
SMI_DBG_SYMS="$DM/drivers/misc/mediatek/smi/Module.symvers"
IOMMU_SYMS="$DM/drivers/misc/mediatek/iommu/Module.symvers"
SDA_SYMS="$DM/drivers/misc/mediatek/sda/Module.symvers"
CMDQ_SYMS="$DM/drivers/misc/mediatek/cmdq/mailbox/Module.symvers"
MDP_SYMS="$DM/drivers/misc/mediatek/mdp/Module.symvers"

build_one "SMI core" \
    M="$DM/drivers/memory" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_DEVICE_MODULES_MTK_SMI=m \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        -I"$DM/include" \
        -I"$DM/include/soc/mediatek" \
        -include "$DM/include/dt-bindings/memory/mtk-memory-port.h" \
        -include "$DM/include/soc/mediatek/smi.h")" \
    mtk-smi.ko
require_file "$DM/drivers/memory/mtk-smi.ko"

build_one "SMI debug" \
    M="$DM/drivers/misc/mediatek/smi" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_DEVICE_MODULES_MTK_SMI=m \
    KBUILD_EXTRA_SYMBOLS="$SMI_CORE_SYMS" \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        -I"$DM/include" \
        -I"$DM/include/soc/mediatek" \
        -include "$DM/include/dt-bindings/memory/mtk-memory-port.h" \
        -include "$DM/include/soc/mediatek/smi.h")" \
    mtk-smi-dbg.ko
require_file "$DM/drivers/misc/mediatek/smi/mtk-smi-dbg.ko"

build_one "IOMMU debug" \
    M="$DM/drivers/misc/mediatek/iommu" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_MTK_IOMMU_MISC_DBG=m \
    CONFIG_DEVICE_MODULES_MTK_SMI=y \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        -I"$DM/include" \
        -I"$DM/include/soc/mediatek" \
        -include "$DM/include/dt-bindings/memory/mtk-memory-port.h" \
        -include "$DM/include/soc/mediatek/smi.h")" \
    iommu_debug.ko
require_file "$DM/drivers/misc/mediatek/iommu/iommu_debug.ko"

build_one "IRQ debug" \
    M="$DM/drivers/misc/mediatek/sda" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_MTK_IRQ_DBG=m \
    CONFIG_MTK_SDA=y \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_MTK_IRQ_DBG=1 \
        -I"$DM/include")" \
    irq-dbg.ko
require_file "$DM/drivers/misc/mediatek/sda/irq-dbg.ko"

build_one "CMDQ mailbox extension" \
    M="$DM/drivers/misc/mediatek/cmdq/mailbox" \
    DEVICE_MODULES_PATH="$DM" \
    MTK_PLATFORM=mt6768 \
    CONFIG_MTK_CMDQ_MBOX_EXT=m \
    CONFIG_MTK_CMDQ_MBOX_EXT_MT6768=m \
    CONFIG_MTK_GZ_TZ_SYSTEM=n \
    CONFIG_VHOST_CMDQ=n \
    CONFIG_VIRTIO_CMDQ=n \
    CONFIG_DEVICE_MODULES_MTK_SMI=y \
    KBUILD_EXTRA_SYMBOLS="$SMI_CORE_SYMS $SMI_DBG_SYMS $IOMMU_SYMS $SDA_SYMS" \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_MTK_CMDQ_MBOX_EXT=1 \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        "${MTK_HEADER_FLAGS[@]}")" \
    mtk-cmdq-drv-ext.ko
require_file "$DM/drivers/misc/mediatek/cmdq/mailbox/mtk-cmdq-drv-ext.ko"

build_one "MDP CMDQ helper interface" \
    M="$DM/drivers/misc/mediatek/mdp" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_MTK_MDP=m \
    CONFIG_MTK_MDP_DUMMY=n \
    CONFIG_DEVICE_MODULES_MTK_SMI=y \
    KBUILD_EXTRA_SYMBOLS="$CMDQ_SYMS $SMI_CORE_SYMS $SMI_DBG_SYMS" \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_MTK_CMDQ_MBOX_EXT=1 \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        "${MTK_HEADER_FLAGS[@]}")" \
    cmdq_helper_inf.ko
require_file "$DM/drivers/misc/mediatek/mdp/cmdq_helper_inf.ko"

build_one "ISP3 camera core" \
    M="$DM/drivers/misc/mediatek/cameraisp/src/isp_3" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_MTK_CAMERA_ISP_RAW_SUPPORT_ISP3_M=m \
    CONFIG_MTK_CAMERA_ISP_RAW_SUPPORT_ISP3_Z=n \
    CONFIG_MTK_CAMERA_ISP_PLATFORM=isp3_m \
    CONFIG_DEVICE_MODULES_MTK_SMI=y \
    KBUILD_EXTRA_SYMBOLS="$MDP_SYMS $CMDQ_SYMS $SMI_CORE_SYMS $SMI_DBG_SYMS $IOMMU_SYMS $SDA_SYMS" \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}" \
        -DCONFIG_MTK_CMDQ_MBOX_EXT=1 \
        -DCONFIG_DEVICE_MODULES_MTK_SMI=1 \
        "${MTK_HEADER_FLAGS[@]}")" \
    modules
require_file "$DM/drivers/misc/mediatek/cameraisp/src/isp_3/camera_isp_3_m.ko"
require_file "$DM/drivers/misc/mediatek/cameraisp/src/isp_3/cam_qos_3.ko"

IMGSENSOR_SENSORS="${AETHER_RMX3171_IMGSENSORS:-ov13b10main_mipi_raw s5k4h7front_mipi_raw w2gc02m1depsj_mipi_raw w2gc02m1microcxt_mipi_raw}"

build_one "RMX3171 ISP3 imgsensor bridge" \
    M="../device-modules/drivers/misc/mediatek/imgsensor/src/isp3_m" \
    DEVICE_MODULES_PATH="$DM" \
    CONFIG_MTK_IMGSENSOR_ISP3_M=m \
    COMMON_VERSION=v1_1 \
    CONFIG_CUSTOM_KERNEL_IMGSENSOR="$IMGSENSOR_SENSORS" \
    KBUILD_EXTRA_SYMBOLS="$DM/drivers/misc/mediatek/cameraisp/src/isp_3/Module.symvers" \
    EXTRA_CFLAGS="$(join_flags "${WARN_FLAGS[@]}")" \
    modules
require_file "$DM/drivers/misc/mediatek/imgsensor/src/isp3_m/imgsensor_isp3_m.ko"

find \
    "$DM/drivers/memory" \
    "$DM/drivers/misc/mediatek/smi" \
    "$DM/drivers/misc/mediatek/iommu" \
    "$DM/drivers/misc/mediatek/sda" \
    "$DM/drivers/misc/mediatek/cmdq/mailbox" \
    "$DM/drivers/misc/mediatek/mdp" \
    "$DM/drivers/misc/mediatek/cameraisp/src/isp_3" \
    "$DM/drivers/misc/mediatek/imgsensor/src/isp3_m" \
    -maxdepth 1 -name '*.ko' -print | sort > "$OUT/aether-camera-experimental-modules.txt"

echo
echo "[+] Experimental camera provider modules: $(wc -l < "$OUT/aether-camera-experimental-modules.txt")"
cat "$OUT/aether-camera-experimental-modules.txt"
