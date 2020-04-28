#!/usr/bin/env bash

# shellcheck source=./lib/os/os.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/os/os.sh"
# fuser -k -9 rootfs-builder/build/rootfs/dev/pts
if ! is_root; then
        log_error "we need root permission to build ${DISTRO+} rootfs.exiting..."
        exit 1
fi
export ARCH=aarch64
export RFS_WIFI_SSID="${WIFI_SSID+x}"
export RFS_WIFI_PASSWORD="${WIFI_PASSWORD+x}"
if [[  -z ${DISTRO+x} ]]; then
    log_warn "DISTRO not set! Using 'debian'";
    export DISTRO="debian"
fi
assert_not_empty DISTRO "${DISTRO}" "distro name must be set"
export time_zone="America/Toronto"
export host_name="pixel-c"
export build_dir="$(pwd)/build"
export rootfs_dir="$build_dir/rootfs"
log_info "distro is set to ${DISTRO}"
log_info "rootfs_dir is set to $rootfs_dir"
if [[ ! -d "$rootfs_dir" ]]; then
  log_warn "rootfs_dir directory  $rootfs_dir not found. creating ..."
  mkdir -p "$rootfs_dir"
fi
if [[ ! -d "$(pwd)/distros/${DISTRO}" ]]; then
  log_error "directory $(pwd)/distros/${DISTRO} not found!";
  distros=($(ls distros))
  log_info "Distros available: ${distros[@]}";
  exit 1
fi
readonly build_script="$(pwd)/distros/${DISTRO}/build.sh"
log_info "setting ownership of '$rootfs_dir' to uid '$UID'"
chown -R "$UID:$UID" "$rootfs_dir" || true >/dev/null 2>&1
source "$build_script"
if [ "$?" -ne "0" ]; then
  exit 1;
fi 
# Chmod
chown -R 0:0 "$rootfs_dir/"
chown -R 1000:1000 "$rootfs_dir/home/pixelc" || true
chown -R 1000:1000 "$rootfs_dir/home/alarm" || true
chmod +s "$rootfs_dir/usr/bin/chfn"
chmod +s "$rootfs_dir/usr/bin/newgrp"
chmod +s "$rootfs_dir/usr/bin/passwd"
chmod +s "$rootfs_dir/usr/bin/chsh"
chmod +s "$rootfs_dir/usr/bin/gpasswd"
chmod +s "$rootfs_dir/bin/umount"
chmod +s "$rootfs_dir/bin/mount"
chmod +s "$rootfs_dir/bin/su"
# pushd "$rootfs_dir"
readonly tar_target="$(pwd)/out/${DISTRO}_rootfs.tar.gz"
readonly tar_target_dir="$(dirname "$rootfs_dir")"
log_info "creating parent directory $tar_target_dir"
mkdir -p "$tar_target_dir"
tar -cpzf "$(pwd)/out/${DISTRO}_rootfs.tar.gz" "$rootfs_dir"
# popd