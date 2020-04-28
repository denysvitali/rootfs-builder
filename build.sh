#!/usr/bin/env bash

# shellcheck source=./lib/os/os.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/os/os.sh"
export ARCH=aarch64
export RFS_WIFI_SSID="${WIFI_SSID+x}"
export RFS_WIFI_PASSWORD="${WIFI_PASSWORD+x}"
assert_not_empty "DISTRO" "${DISTRO+x}" "distro name must be set"
readonly SYSROOT="/tmp/rootfs"
log_info "distro is set to $DISTRO"
log_info "SYSROOT is set to $SYSROOT"
if [[ ! -d "$SYSROOT" ]]; then
  log_warn "SYSROOT directory  $SYSROOT not found. creating ..."
  mkdir -p "$SYSROOT"
fi
if [[ ! -d "$(pwd)/distros/$DISTRO" ]]; then
  log_error "directory $(pwd)/distros/$DISTRO not found!";
  distros=$(ls distros)
  log_info "Distros available: $distros";
  exit 1
fi
readonly build_script="$(pwd)/distros/$DISTRO/build.sh"
log_info "setting ownership of '$SYSROOT' to uid '$UID'"
sudo chown -R "$UID:$UID" "$SYSROOT"
source "$build_script"
if [ "$?" -ne "0" ]; then
  exit 1;
fi 
# Chmod
sudo chown -R 0:0 "$SYSROOT/"
sudo chown -R 1000:1000 "$SYSROOT/home/pixelc" || true
sudo chown -R 1000:1000 "$SYSROOT/home/alarm" || true
sudo chmod +s "$SYSROOT/usr/bin/chfn"
sudo chmod +s "$SYSROOT/usr/bin/newgrp"
sudo chmod +s "$SYSROOT/usr/bin/passwd"
sudo chmod +s "$SYSROOT/usr/bin/chsh"
sudo chmod +s "$SYSROOT/usr/bin/gpasswd"
sudo chmod +s "$SYSROOT/bin/umount"
sudo chmod +s "$SYSROOT/bin/mount"
sudo chmod +s "$SYSROOT/bin/su"
# pushd "$SYSROOT"
readonly tar_target="$(pwd)/out/${DISTRO}_rootfs.tar.gz"
readonly tar_target_dir="$(dirname "$SYSROOT")"
log_info "creating parent directory $tar_target_dir"
mkdir -p "$tar_target_dir"
sudo tar -cpzf "$(pwd)/out/${DISTRO}_rootfs.tar.gz" "$SYSROOT"
# popd