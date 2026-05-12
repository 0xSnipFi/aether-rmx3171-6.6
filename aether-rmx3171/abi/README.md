# KMI ABI allowlist

A16 GKI 2.0 requires kernel modules to bind against a frozen Kernel Module
Interface (KMI). The allowlist is the set of `__ksymtab_*` symbols that
vendor_dlkm modules may use.

## How to generate

```bash
cd kernel-6.6
make ARCH=arm64 CC=clang LLVM=1 O=../out \
    aether_rmx3171_base_defconfig
make ARCH=arm64 CC=clang LLVM=1 O=../out -j$(nproc) Image modules

# Extract symbol list
build/abi/extract_symbols ../out/vmlinux \
    > ../aether-rmx3171/abi/abi_gki_aarch64_aether
```

(`build/abi/extract_symbols` ships with Samsung's kernel — adapt path.)

## Files

- `abi_gki_aarch64_aether` — symbol allowlist (one symbol per line)
- `abi_gki_aarch64_aether.xml` — full ABI dump with type info (optional)

## Status

⚠ **EMPTY** — generated lazily after a successful build, then committed.
A16 GKI compliance check is offline-relaxed for community kernels; CTS-on-GSI
would flag missing allowlist.

## What goes in here

Common KMI symbols for our hardware:

```
__ksymtab_mtk_iommu_get_dma_cookie
__ksymtab_mtk_pmic_keys_pwrkey
__ksymtab_mt6358_get_chip_id
__ksymtab_mtk_charger_get_property
__ksymtab_drm_mipi_dsi_attach
__ksymtab_clk_register_branch
__ksymtab_pinctrl_register
__ksymtab_regulator_get
__ksymtab_kthread_create_on_node
... (a few thousand symbols)
```
