# Samsung Kleaf/Bazel build (full MTK BSP)

This is the **proper production build path** for getting all MediaTek MT6768
BSP drivers (camera ISP, Mali GPU, MT6370 charger, sensor hub, MT6768
connsys WiFi/BT, etc.) compiled as loadable kernel modules.

Samsung's Kleaf is a Bazel-based wrapper around Linux kbuild. It manages
the cross-tree dependency between `kernel-6.6/` (Linux base) and
`kernel_device_modules-6.6/` (MTK BSP modules).

## Why Kleaf is required

Plain `make M=device-modules modules` fails because:
- Each of ~141 MTK driver directories has unique `-I` include paths Kleaf auto-sets
- Some drivers depend on Module.symvers from siblings
- Build order matters (clk → pinctrl → regulator → consumers)
- Samsung's Bazel rules handle all of this

## Prerequisites (~20-25 GB total)

1. **Bazelisk** (auto-fetches correct Bazel version)
   ```bash
   curl -L -o ~/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
   chmod +x ~/bin/bazel
   echo '6.5.0' > kernel-6.6/.bazelversion  # Kleaf wants Bazel 6.x
   ```

2. **Android Clang prebuilt** (~3 GB)
   ```bash
   cd <samsung-kleaf-workspace>/prebuilts
   git clone --depth=1 --no-checkout \
       https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
       clang/host/linux-x86
   cd clang/host/linux-x86
   git sparse-checkout init --cone
   git sparse-checkout set kleaf clang-r510928   # or r522817 fallback
   git checkout
   ```

3. **Android build-tools** (~500 MB)
   ```bash
   cd <prebuilts>
   git clone --depth=1 \
       https://android.googlesource.com/platform/prebuilts/build-tools
   ```

4. **Kernel build-tools** (~200 MB) — bazel binary + utils
   ```bash
   git clone --depth=1 \
       https://android.googlesource.com/kernel/prebuilts/build-tools \
       prebuilts/kernel-build-tools
   ```

5. **Bazel external deps** (~2 GB) — bazel-skylib, rules_python, etc.
   ```bash
   cd <samsung-kleaf-workspace>/external
   git clone https://github.com/bazelbuild/bazel-skylib bazel-skylib
   git clone https://github.com/bazelbuild/rules_python rules_python
   # See workspace.bzl for full list
   ```

6. **JDK 11+** for Bazel
   ```bash
   sudo apt-get install -y openjdk-17-jdk
   ```

## Build

After all prereqs staged:

```bash
cd <samsung-kleaf-workspace>
export DEFCONFIG_OVERLAYS='mt6768_overlay.config RMX3171.config'
export MODE=user
export KERNEL_VERSION=kernel-6.6
export SOURCE_DATE_EPOCH=$(date +%s)
bash build_kernel.sh
```

Build duration: ~30-90 min depending on CPU.

Output: `out/target/product/<board>/obj/KLEAF_OBJ/dist/`

## Adapting Samsung's Kleaf target for RMX3171

Samsung's default target builds for board `a05m` with overlay
`S96818AA1.config`. To produce RMX3171:

### 1. Create RMX3171.config

```bash
cp device-modules/kernel/configs/S96818AA1.config \
   device-modules/kernel/configs/RMX3171.config
# Edit to match RMX3171 hardware (touch chip, panel, charger, etc.)
```

### 2. Create RMX3171.dts

```bash
cp device-modules/arch/arm64/boot/dts/mediatek/S96818AA1.dts \
   device-modules/arch/arm64/boot/dts/mediatek/RMX3171.dts
# Replace Samsung GPIO/pinctrl/sensor specifics with RMX3171 values from
# docs/01_hardware_truth.md and stock dtbdump
```

### 3. Create board entry in Bazel build

In `device-modules/BUILD.bazel`, add `mgk_64_k66_rmx3171_*` targets paralleling `mgk_64_k66_a05m_*`. Point to RMX3171.dts and RMX3171.config.

### 4. Build RMX3171 target

```bash
export DEFCONFIG_OVERLAYS='mt6768_overlay.config RMX3171.config'
bash build_kernel.sh
```

## Disk + bandwidth budget

- Samsung sources (already in this repo): 2 GB
- Android prebuilts (one-time download): 5-8 GB
- Bazel `.cache/` (first build): 3-5 GB
- Build output: 3-5 GB
- **Total: 15-25 GB** on a clean machine

## Known issues

- Bazel 9.x not compatible (use 6.5.0 via Bazelisk + .bazelversion)
- Samsung's tools/bazel wrapper needs `gettop.sh` symlinked to workspace root
- Some EXT_MODULES paths (fpsgo_int, sched_int, hbt_driver) are Samsung-proprietary and not in the open release — they get stripped by build_kernel.sh automatically

## Why this isn't in the repo by default

Android prebuilts are too large to redistribute (and have their own licenses).
Users must fetch them following AOSP repo manifest workflows. This guide
walks the minimum viable subset.

## Help wanted

PRs to automate the Kleaf prereq fetch (one script that downloads everything)
are welcome. See [CONTRIBUTING.md](../CONTRIBUTING.md).
