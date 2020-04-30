#!/usr/bin/env bash

# shellcheck source=./lib/fast_apt/fast_apt.sh
source "$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]+x}")")")" && pwd)/lib/fast_apt/fast_apt.sh"
cat "distros/${DISTRO}/logo"
readonly code_name="buster"
readonly main_dependancies=(
    "bash"
    "bluez"
    "sudo"
    "binutils"
    "ubuntu-minimal"
    "network-manager"
    "lightdm"
    "lightdm-gtk-greeter"
    "openbox"
    "onboard"
    "ssh" 
    "net-tools" 
    "ethtool" 
    "wireless-tools" 
    "init" 
    "iputils-ping" 
    "rsyslog" 
    "bash-completion" 
    "ifupdown" 
    "systemd"
)
readonly systemd_services=(
    "NetworkManager"
    "lightdm"
    "bluetooth"
    "dhcpcd"
)
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

function timezone_setup(){
    local -r zone="$1"
    assert_not_empty "zone" "${zone+x}" "time zone must be set"
    log_info "setting timezone to $zone"
    local -r target="$rootfs_dir/etc/timezone"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    echo "$zone" > "$target"
}
function prepare_rootfs(){
    log_info "preparing rootfs..."
    log_info "installing dependancies..."
    local -r packages=(
        "debootstrap"
        "binfmt-support"
        "qemu-user-static"
    )
    fast_apt "install" "${packages[@]}"
    update-binfmts --enable qemu-aarch64
    teardown_mounts || true > /dev/null 2>&1
    log_info "cleaning up rootfs directory '$rootfs_dir' if it exists ..."
    rm -rf "$rootfs_dir"
    log_info "crearting rootfs directory '$rootfs_dir'..."
    mkdir -p "$rootfs_dir"
    log_info "setting up keyring for debian "$code_name"..."
    qemu-debootstrap --include=debian-archive-keyring --arch arm64 "$code_name" "$rootfs_dir" || true
}
function setup_mounts(){
    teardown_mounts || true > /dev/null 2>&1
    log_info "setting up mounts..."
    pushd "$rootfs_dir" >/dev/null 2>&1
        mount -t sysfs sys sys/  >/dev/null 2>&1
        mount -t proc  proc proc/ >/dev/null 2>&1
        mount -o bind /dev dev/ >/dev/null 2>&1
        mount -o bind /dev/pts dev/pts >/dev/null 2>&1
    [[ "$?" != 0 ]] && popd
    popd >/dev/null 2>&1
}
function teardown_mounts(){
    log_info "tearing down mounts..."
    pushd "$rootfs_dir" >/dev/null 2>&1
        umount -lf "${rootfs_dir}/sys"
        umount -lf "${rootfs_dir}/proc"
        umount -lf "${rootfs_dir}/dev"
        # umount -lf "${rootfs_dir}/dev/pts"
        # umount -lf "${rootfs_dir}/dev"
    [[ "$?" != 0 ]] && popd
    popd >/dev/null 2>&1
}

function enable_systemd_services(){
    local -r services="$1"
    for i in "${services[@]}"; do
        log_info "enabling service $i"
        chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" \
            systemctl enable "$i"
    done
}
function hostname_setup(){
    local -r host="$1"
    assert_not_empty "host" "${host+x}" "host must be set"
    log_info "Setting hostname to $host"
    local -r target="$rootfs_dir/etc/hostname"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    # echo "$host" > "$target"
cat > "$target" <<EOF
    127.0.0.1       localhost
    ::1             localhost ip6-localhost ip6-loopback
    ff02::1         ip6-allnodes
    ff02::2         ip6-allrouters
    127.0.1.1       $host_name
EOF
    chroot "$rootfs_dir" env -i /bin/hostname hostname

}
function install_packages(){
    log_info "installing base packages ..."
    chroot "$rootfs_dir" apt-get update
    chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" \
            DEBIAN_FRONTEND="noninteractive" \
        apt-get --yes \
            -o DPkg::Options::=--force-confdef \
            install  --no-install-recommends whiptail
    chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" \
        apt-get --yes \
            -o DPkg::Options::=--force-confdef install \
            --no-install-recommends locales
    chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" SHELL="/bin/bash" \
        dpkg-reconfigure locales
    chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" \
        apt-get --yes -o DPkg::Options::=--force-confdef install \
        --no-install-recommends "${main_dependancies[@]}"\
    chroot "$rootfs_dir" \
        env -i HOME="/root" \
            PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
            TERM="$TERM" \
        apt-get --yes -o DPkg::Options::=--force-confdef upgrade
    log_info "clearning up after apt ..."
    chroot "$rootfs_dir" apt-get --yes clean
    chroot "$rootfs_dir" apt-get --yes autoclean
    chroot "$rootfs_dir" apt-get --yes autoremove
}
function setup_user(){
    chroot "$rootfs_dir" useradd -G sudo,adm -m -s /bin/bash "pixel"
    chroot "$rootfs_dir" sh -c "echo 'pixel:pixel' | chpasswd"
}
function keyboard_setup(){
    log_info "Adding Keyboard to LightDM"
    local target="$rootfs_dir/etc/lightdm/lightdm-gtk-greeter.conf"
    local dir="$(dirname "$target")"
    local -r KB_LAYOUT="us"
    local -r KB_MAP="pc104"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    sed -i 's/#keyboard=/keyboard=onboard/' "$target"
    log_info "setting x11 Keyboard to conf"
    target="/etc/X11/xorg.conf.d/00-keyboard.conf"
    dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
cat > "$target" <<EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$KB_LAYOUT"
        Option "XkbModel" "$KB_MAP"
EndSection
EOF
}
function wifi_setup(){
    log_info "setting up Wi-Fi connection"
    local wifi_ssid="$1"
    local wifi_password="$2"
    if [[  $(string_is_empty_or_null "${wifi_ssid+x}") ]]; then
        log_warn "WIFI SSID not set! Using 'Pixel C'";
        wifi_ssid="Pixel C"
    fi
    if [[  $(string_is_empty_or_null "${wifi_password+x}") ]]; then
        log_warn "WIFI Password not set! Using 'connectme!'";
        wifi_password="connectme!"
    fi
    local -r target="$rootfs_dir/etc/NetworkManager/system-connection/wifi-conn-1"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
cat > "$target" <<EOF
[connection]
id=wifi-conn-1
uuid=4f1ca129-1d42-4b8b-903f-591640da4015
type=wifi
permissions=
[wifi]
mode=infrastructure
ssid=$wifi_ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$wifi_password

[ipv4]
dns-search=
method=auto

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto
EOF
}

function setup_alarm(){
    log_info "setting up alarm"
    local -r target="$rootfs_dir/home/alarm/.config/openbox/autostart"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
cat > "$target" <<EOF 
kitty &
onboard &
EOF
}

function setup_bcm4354(){
    log_info "Adding BCM4354.hcd"
    local -r target="$rootfs_dir/lib/firmware/brcm/BCM4354.hcd"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    local -r url="https://github.com/denysvitali/linux-smaug/blob/v4.17-rc3/firmware/bcm4354.hcd?raw=true"
    log_info "downloading $url"
    wget -O "$target" "$url"
}
function cleanup(){
    local -r target="$rootfs_dir/var/cache"
    log_info "Removing /var/cache/ content"
    rm -rf "$target"
    mkdir -p "$target"
}
############################################# start ###############################################


log_info "making build directory $build_dir"
mkdir -p "$build_dir"
pushd "$build_dir" >/dev/null 2>&1
    prepare_rootfs
    setup_mounts
    timezone_setup "${time_zone}"
    hostname_setup "${host_name}"
    install_packages
    setup_user
    enable_systemd_services "${systemd_services[@]}"
    keyboard_setup
    wifi_setup "${RFS_WIFI_SSID}" "${RFS_WIFI_PASSWORD}" 
    setup_alarm
    setup_bcm4354
    cleanup
    log_info "leaving chroot"
    exit
    teardown_mounts
[[ "$?" != 0 ]] && popd
popd >/dev/null 2>&1
log_info "RootFS generation completed."


# OLDPATH="$PATH"
# if [ -z "$KBD_BT_ADDR" ]; then
#   log_info "Configuring BT Keyboard"
#   cat > $rootfs_dir/etc/btkbd.conf <<EOF
# BTKBDMAC = ''$KBD_BT_ADDR''
# EOF
#   log_info "=> Adding BT Keyboard service"
#   cat > $rootfs_dir/etc/systemd/system/btkbd.service <<EOF
# [Unit]
# Description=systemd Unit to automatically start a Bluetooth keyboard
# Documentation=https://wiki.archlinux.org/index.php/Bluetooth_Keyboard
# ConditionPathExists=/etc/btkbd.conf
# ConditionPathExists=/usr/bin/bluetoothctl

# [Service]
# Type=oneshot
# EnvironmentFile=/etc/btkbd.conf
# ExecStart=/usr/bin/bluetoothctl connect ${BTKBDMAC}

# [Install]
# WantedBy=bluetooth.target
# EOF
#   run_in_qemu systemctl enable btkbd
# fi

unset RFS_WIFI_SSID
unset RFS_WIFI_PASSWORD
unset code_name
unset time_zone
unset host_name
unset deb_arch
unset packages
unset systemd_services