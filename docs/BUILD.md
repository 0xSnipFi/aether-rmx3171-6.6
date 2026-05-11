# Build guide — AETHER RMX3171 6.6

Two build paths exist. Pick based on your goal.

| Path | Output | Hardware works? | Effort |
|---|---|---|---|
| **A: Plain make (base kernel only)** | `Image.gz-dtb` + 120 generic Linux modules + DTB + AnyKernel3 zip | ❌ no MTK hardware drivers — kernel boots to console then stalls at first-stage mount | 30 min setup, 30 min build |
| **B: Samsung Kleaf/Bazel (full BSP)** | Same + ~500 MTK BSP modules (camera, GPU, charger, sensors, WiFi, etc.) | ✅ hardware likely works after DTS tuning + device test iteration | Multi-hour setup, multi-hour build, +20 GB Android prebuilts download |

## Path A: Plain make

### 1. Host prereqs

Ubuntu 22.04 host (WSL2 OK, on **ext4** filesystem — NTFS will lose case-sensitive files).

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential bc bison flex libssl-dev libelf-dev \
    libncurses-dev xz-utils kmod cpio python3 zip rsync \
    clang lld llvm dwarves \
    gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi git curl
```

### 2. Stage Samsung base

```bash
# Download Samsung A055F open-source kernel from
# https://opensource.samsung.com (search SM-A055F)
unzip SM-A055F_15_Opensource.zip -d /path/to/extracted
export SAMSUNG_KERNEL_ROOT=/path/to/extracted/SM-A055F_15_Opensource/Kernel
bash scripts/sync_samsung_base.sh
```

### 3. Fetch KernelSU

```bash
cd kernel-6.6 && curl -LSs https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh | bash
cd ..
```

### 4. Build

```bash
bash aether-rmx3171/build/build_aether_6_6.sh
```

Output:
- `out/arch/arm64/boot/Image` (raw ELF, ~27 MB)
- `out/arch/arm64/boot/Image.gz` (~12 MB)
- `out/arch/arm64/boot/Image.gz-dtb` (concat, ~12 MB)
- `out/arch/arm64/boot/dts/mediatek/mt6768-rmx3171.dtb` (~160 KB)
- ~120 `.ko` files

### 5. Package

```bash
bash scripts/package_anykernel.sh
# Output: out/AETHER_X_RMX3171_6.6_A16-YYYYMMDD.zip
```

## Path B: Full Samsung Kleaf build

Required for working MTK hardware. See [KLEAF_BUILD.md](KLEAF_BUILD.md).

## Common build errors

### "linux/netfilter/xt_mark.h: file not found"

NTFS case-collision. The original NTFS source lost lowercase match
headers when collision with `xt_MARK.h`. Fix:

```bash
bash aether-rmx3171/build/restore_lost_headers.sh
```

### "mtk_signing_key.pem: No such file or directory"

Samsung's defconfig hardcodes their MTK build-server signing key path.
AETHER overlay overrides this:

```
CONFIG_MODULE_SIG_KEY="certs/signing_key.pem"
# CONFIG_MODULE_SIG_PROTECT is not set
CONFIG_MODULE_SIG_ALL=y
```

Verify your `.config` after merge_config.

### "make[N]: *** [.../arch/arm64/boot/dts/allwinner/...] Error"

Unrelated to our target. Build only the mediatek DTB:

```bash
make ARCH=arm64 ... -j16 mediatek/mt6768-rmx3171.dtb
```

### "Make section mismatch errors non-fatal [Y/n]?" prompt

Interactive Kconfig prompt. AETHER overlay sets:

```
CONFIG_SECTION_MISMATCH_WARN_ONLY=y
# CONFIG_WERROR is not set
```

If you see the prompt, refresh:

```bash
make ARCH=arm64 ... olddefconfig
```

## Toolchain notes

- Samsung A055F was built with Android Clang r510928 (clang 18.0.0). Plain
  make works with stock Ubuntu clang-14 / clang-15 / clang-18.
- LLD must match clang major version.
- pahole 1.25+ required for BTF generation (`CONFIG_DEBUG_INFO_BTF=y`).

## Cross-compile environment

```bash
export ARCH=arm64
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
```

## Reproducible build flags

```bash
SOURCE_DATE_EPOCH=$(date -u -d "$(git log -1 --format=%cI)" +%s) \
    bash aether-rmx3171/build/build_aether_6_6.sh
```
