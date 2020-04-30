# RootFS Builder

<div align="center">
  <strong>A simple RootFS builder for many distros</strong>
</div>
<p align="center">
  <a href="https://gitpod.io#https://github.com/da-moon/rootfs-builder">
    <img src="https://img.shields.io/badge/open%20in-gitpod-blue?logo=gitpod" alt="Open In GitPod">
  </a>
  <img src="https://img.shields.io/github/languages/code-size/da-moon/rootfs-builder" alt="GitHub code size in bytes">
  <img src="https://img.shields.io/github/commit-activity/w/da-moon/rootfs-builder" alt="GitHub commit activity">
  <img src="https://img.shields.io/github/last-commit/da-moon/rootfs-builder/master" alt="GitHub last commit">
</p>

## manjaro based root-fs tar.gz creation

- install instruction set's dependant packages : `aria2(1.25.0>=)` `fastboot` `adb`
- you can find manjaro arm downloads at this [link](https://osdn.net/projects/manjaro-arm/storage/pbpro/). choose the edition you prefer. in this quide , I will be using `kde-plasma` with version `20.02` found at this [link](https://osdn.net/projects/manjaro-arm/storage/pbpro/kde-plasma/20.02/).

> **[WARN]** do not choose emmc installer , choose the other image. e.g. `Manjaro-ARM-kde-plasma-pbpro-20.02.img.xz`

the following snippet uses `aria2` to quickly download it and save it as `manjaro.img.xz` under `/tmp` directory

```bash
export manjaro_out_name="manjaro"; \
export manjaro_dir="/tmp"; \
export manjaro_url="https://osdn.net/projects/manjaro-arm/storage/pbpro/kde-plasma/20.02/Manjaro-ARM-kde-plasma-pbpro-20.02.img.xz"; \
aria2c -c \
       -j16 \
       -x16 \
       -k 1M \
       --out="${manjaro_out_name}.img.xz" \
       --dir="$manjaro_dir" \
       "$manjaro_url"; \
unset manjaro_url;
```

- extract the downloaded image

```bash
unxz "${manjaro_dir}/${manjaro_out_name}.img.xz"
```

- we need to calculate offeset to mount the image. use `fdisk -l` to probe images information. you would need `sector size` and `boot start` values. starting offset for mount is equal to `(boot start) x (sector size)`

- you can use the following snippet to get sector size 

```bash
fdisk -l "${manjaro_dir}/${manjaro_out_name}.img" | grep -Po '(?<= \= )[^ bytes]+'
```

- you can use the following snippet to get boot start 

```bash
fdisk -l "${manjaro_dir}/${manjaro_out_name}.img" | grep -v 'sectors' | grep "${manjaro_dir}/${manjaro_out_name}" |  tr -s ' ' | cut -d ' ' -f2
```

- mount the image based on calculated offset

```bash
export offset="32000000"; \
sudo mkdir -p "/mnt/${manjaro_out_name}"; \
sudo mount -o loop,offset="${offset}" "${manjaro_dir}/${manjaro_out_name}.img" "/mnt/${manjaro_out_name}";
unset offset;
```

- change directory and archive whatever was inside the mounted directory

> **[WARN]** make sure symlinks are preserved after archiving

```bash
pushd "/mnt/${manjaro_out_name}"; \
sudo tar -zcvf "/tmp/${manjaro_out_name}.tar.gz" . ; \
popd; \
sudo umount /mnt/${manjaro_out_name}; \
sudo rm -rf /mnt/${manjaro_out_name}; \
rm "/tmp/${manjaro_out_name}.img"; \
sudo chown "$UID" "/tmp/${manjaro_out_name}.tar.gz";
```
## setting up your distro on the device

- `Enable USB debugging` and `OEM Unlock` on your pixel c device.
- exit `pixel-c` container if your shell is still in it. you can use the following snippet
- download `twrp recovery` from this [link](https://dl.twrp.me/dragon/). 
- boot twrp recovery by running the following snippet

```bash
fastboot boot twrp.img
```

- wipe you `/data/` partition. in twrp recovery, there is a `wipe` option. go there and `factory reset` device
- mount `/data/` and `/cache/` in twrp
- download [`busybox`](https://busybox.net/downloads/binaries/) static build for armv8 just in case busybox in twrp has any issue. as an example , the following snippet downloads `busybox 1.31.0`

```bash
export busybox_version=1.31.0; \
export busybox_url="https://busybox.net/downloads/binaries/${busybox_version}-defconfig-multiarch-musl/busybox-armv8l"; \
aria2c -c \
       -j16 \
       -x16 \
       -k 1M \
       --out="busybox" \
       --dir="$manjaro_dir" \
       "$busybox_url"; \
unset busybox_url;unset busybox_version
```

- move `busybox` to `/cache/` and generated rootfs to `/data/` your device and then use `adb shell` to get a shell into your pixel c . you can use the following snippet

```bash
export rootfs="arch_rootfs.tar.gz"; \
adb push "/tmp/${manjaro_out_name}.tar.gz" /data/ && \
adb push /tmp/busybox /cache/ && \
adb shell
```

- run the follwing in adb shell ( on your device ) to extract rootfs

```bash
rootfs="arch_rootfs.tar.gz"; \
chmod +x /cache/busybox && \
cd /data && \
/cache/busybox tar xvf "$rootfs" && \
rm "$rootfs" && \
exit; \
unset rootfs;
```

- reboot to bootloader to flash boot image 

```bash
adb reboot bootloader
```

- flash a signed boot image with fastboot. you can use the following snippet

```bash
export boot_image=boot.img; \
fastboot flash boot "$boot_image" ; \
unset  boot_image;
```

- clean up env vars

```bash
unset manjaro_out_name;unset manjaro_dir;
```
