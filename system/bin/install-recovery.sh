#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:67108864:b05bc9f683d7da40a5b7dcfdf910a8a91a816506; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/bootdevice/by-name/boot:67108864:048e3118ab4346b6edb826d7788c9bdc5dada1db EMMC:/dev/block/bootdevice/by-name/recovery b05bc9f683d7da40a5b7dcfdf910a8a91a816506 67108864 048e3118ab4346b6edb826d7788c9bdc5dada1db:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
