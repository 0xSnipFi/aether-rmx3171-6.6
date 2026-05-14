### AETHER RMX3171 6.6 - AnyKernel3 installer
### Realme Narzo 30A (RMX3171) / oppo6769 / MT6768
### Stock layout: non-A/B boot-header-v2, physical boot + dtbo

properties() { '
kernel.string=AETHER 6.6 for Realme Narzo 30A (RMX3171)
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=RMX3171
device.name2=RMX3171L1
device.name3=narzo30a
device.name4=narzo_30a
device.name5=oppo6769
supported.versions=11-16
supported.patchlevels=
'; }

block=auto;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

no_block_display=1;

. tools/ak3-core.sh;

dump_boot;
write_boot;

