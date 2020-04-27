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

## setup lxc container

- create a container called `pixel-c`

```bash
lxc launch images:debian/buster pixel-c
```

- create volume for the `pixel-c` container. use `pixel-c` as volume's name

```bash
export name="pixel-c"; \
lxc storage volume create default "$name"; \
unset name;
```

- mount `pixel-c`  volume to `pixel-c` container

```bash
export name="pixel-c"; \
export container="pixel-c"; \
export path_parent="/mnt/"; \
lxc config device add "$container" "$name" disk pool=default source="$name" path="$path_parent/$name"; \
unset name;unset container;unset path_parent;
```

- mount  `pixel-c` volume to host os / host container

> I use a 'master' lxc container as my main environment. create 
  so I bind the volume to my master container using the above snippet. In case you use you host os as your main environment, bind the volume to it.

- set permissions for the newly mounted folder on you host os

> at this point, you should have a folder called `pixel-c` in `pixel-c` container at `/mnt/` and you should also have a folder at location of you choosing in your host environment. in your host environment , execute the following to take ownership of the created folder 

```bash
export name="pixel-c"; \
sudo chown $USER:$USER pixel-c -R ; \
unset name;
```

- get a shell into `pixel-c` container by running the following snippet

```bash
export container="pixel-c"; \
lxc exec "$container" bash;
```

- run the following snippet into `pixel-c` container to setup some base dependancies

```bash
apt update && apt install -y curl sudo && $(curl -fsSL https://raw.githubusercontent.com/da-moon/core-utils/master/bin/fast-apt | bash -s -- --init);
```
- execute the `rootfs build script` section of this guide inside `pixel-c` container

## rootfs build script

the following snippet will build debian rootfs. 
set environment variables accordingly

```bash
export DISTRO="debian"; \
export WIFI_SSID=<your wifi ssid>; \
export WIFI_PASSWORD=<your wifi password>; \
rm -rf rootfs-builder; \
git clone https://github.com/da-moon/rootfs-builder; \
pushd rootfs-builder; \
./build.sh; \
popd; \
unset DISTRO;unset WIFI_SSID;unset WIFI_PASSWORD;
```

## setting up your distro on the device

- `Enable USB debugging` and `OEM Unlock` on your pixel c device.
- exit `pixel-c` container if your shell is still in it. you can use the following snippet

```bash
exit; \
unset container;
```

- install `adb` and `fastboot` in your host environment. in case you are using a debian based distro, you can use the following snippet

```bash
sudo apt update && sudo apt install -y adb fastboot
```

- boot your device in `fastboot` mode. you can do so either by holding `power botton + volume down` or by connecting it to your computer while booted in android and using the following adb command :

```bash
adb reboot bootloader
```

- make sure bootloader is unlocked by running the following snippet
> [WARNING] in case it is not unlocked, this snippet will unlock bootloader and dring the process, it will remove all user data. 

```bash
fastboot flashing unlock
```

- download `twrp recovery` from this [link](https://dl.twrp.me/dragon/). 
- boot twrp recovery by running the following snippet

```bash
fastboot boot twrp.img
```

- wipe you `/data/` partition. in twrp recovery, there is a `wipe` option. go there and `factory reset` device
- mount `/data/` and `/cache/` in twrp
- download [`busybox`](https://busybox.net/downloads/binaries/) static build for armv8 just in case busybox in twrp has any issue. in case you have `wget` installed, you can use the following snippet

```bash
export busybox_version=1.31.0; \
export busybox_url="https://busybox.net/downloads/binaries/${busybox_version}-defconfig-multiarch-musl/busybox-armv8l"; \
wget -O busybox "$busybox_url"; \
unset busybox_version;unset busybox_url;
```

- move `busybox` to `/cache/` and generated rootfs to `/data/` your device and then use `adb shell` to get a shell into your pixel c . you can use the following snippet

```
export rootfs="arch_rootfs.tar.gz"; \
adb push "$rootfs" /data/ && \
adb push busybox /cache/ && \
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