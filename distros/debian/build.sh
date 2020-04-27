#!/usr/bin/env bash

# shellcheck source=./lib/os/os.sh
source "$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)/lib/os/os.sh"
cat "distros/$DISTRO/logo"
readonly DISTRO_NAME="Debian"
readonly code_name="buster"
readonly time_zone="America/Toronto"
readonly host_name="pixel-c"
readonly deb_arch="arm64"

readonly packages=(
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
)
readonly systemd_services=(
    "NetworkManager"
    "lightdm"
    "bluetooth"
    "dhcpcd"
)
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
function run_in_qemu(){
    # TODO use local variables
    PROOT_NO_SECCOMP=1 \
    proot -0 -r "$SYSROOT" \
    -q "qemu-$ARCH-static" \
    -b /etc/resolv.conf \
    -b /etc/mtab \
    -b /proc \
    -b /sys "$*"
}
function enable_systemd_services(){
    local -r services="$1"
    for i in "${services[@]}"; do
        log_info "enabling service $i"
        run_in_qemu systemctl enable "$i"
    done
}
function timezone_setup(){
    local -r zone="$1"
    log_info "setting timezone to $zone"
    local -r target="$SYSROOT/etc/timezone"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    echo "$zone" > "$target"
}
function hostname_setup(){
    local -r host="$1"
    log_info "Setting hostname to $host"
    local -r target="$SYSROOT/etc/hostname"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    echo "$host" > "$target"
}
function keyboard_setup(){
    log_info "Adding Keyboard to LightDM"
    local target="$SYSROOT/etc/lightdm/lightdm-gtk-greeter.conf"
    local dir="$(dirname "$target")"
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
    local -r target="$SYSROOT/etc/NetworkManager/system-connection/wifi-conn-1"
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
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

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
    local -r target="$SYSROOT/home/alarm/.config/openbox/autostart"
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
    local -r target="$SYSROOT/lib/firmware/brcm/BCM4354.hcd"
    local -r dir="$(dirname "$target")"
    log_info "creating parent directory $dir"
    mkdir -p "$dir"
    local -r url="https://github.com/denysvitali/linux-smaug/blob/v4.17-rc3/firmware/bcm4354.hcd?raw=true"
    log_info "downloading $url"
    wget -O "$target" "$url"
}
function cleanup(){
    local -r target="$SYSROOT/var/cache"
    log_info "Removing /var/cache/ content"
    rm -rf "$target"
    mkdir -p "$target"
}
if [[  $(string_is_empty_or_null "$RFS_WIFI_SSID") ]]; then
  log_warn "WIFI SSID not set! Using 'Pixel C'";
  WIFI_SSID="Pixel C"
fi
if [[  $(string_is_empty_or_null "$RFS_WIFI_SSID") ]]; then
  log_warn "WIFI SSID not set! Using 'Pixel C'";
  WIFI_SSID="Pixel C"
fi
log_info "running debootstrap for '$deb_arch' architecture with debian codename '$code_name'"
debootstrap --arch "$deb_arch" "$code_name" "$SYSROOT"

OLDPATH="$PATH"

$(timezone_setup "$time_zone")
run_in_qemu apt-get update
run_in_qemu apt-get upgrade
exit 1
log_info "Installing base packages ${packages[@]}"
run_in_qemu apt-get install -y "${packages[@]}"
$(hostname_setup "$host_name")
$(enable_systemd_services "${systemd_services[@]}")
$(keyboard_setup)
$(wifi_setup)

if [ -z "$KBD_BT_ADDR" ]; then
  log_info "Configuring BT Keyboard"
  
  cat > $SYSROOT/etc/btkbd.conf <<EOF
BTKBDMAC = ''$KBD_BT_ADDR''
EOF
  log_info "=> Adding BT Keyboard service"

  cat > $SYSROOT/etc/systemd/system/btkbd.service <<EOF
[Unit]
Description=systemd Unit to automatically start a Bluetooth keyboard
Documentation=https://wiki.archlinux.org/index.php/Bluetooth_Keyboard
ConditionPathExists=/etc/btkbd.conf
ConditionPathExists=/usr/bin/bluetoothctl

[Service]
Type=oneshot
EnvironmentFile=/etc/btkbd.conf
ExecStart=/usr/bin/bluetoothctl connect ${BTKBDMAC}

[Install]
WantedBy=bluetooth.target
EOF
  run_in_qemu systemctl enable btkbd
fi

if [ ! -z "$KB_LAYOUT" -o -! -z "$KB_MAP" ]; then
  KB_LAYOUT = "ch"
  KB_MAP = "de"
fi
$(setup_alarm)
$(setup_bcm4354)
$(cleanup)
log_info "RootFS generation done."
unset RFS_WIFI_SSID
unset RFS_WIFI_PASSWORD
unset DISTRO_NAME
unset code_name
unset time_zone
unset host_name
unset deb_arch
unset packages
unset systemd_services