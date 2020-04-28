#!/usr/bin/env bash
# shellcheck source=./lib/env/env.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/env/env.sh"
# shellcheck source=./lib/log/log.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/log/log.sh"
# shellcheck source=./lib/io/io.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/file/file.sh"
# shellcheck source=./lib/string/string.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/string/string.sh"
function is_root() {
    [ "$EUID" == 0 ]
}
function os_command_is_available() {
    local name
    name="$1"
    command -v "$name" >/dev/null
}
function has_sudo() {
    os_command_is_available "sudo"
}
function has_apt() {
    os_command_is_available "apt-get"
}
function has_parallel() {
    os_command_is_available "parallel"
}
function is_pkg_installed() {
    local -r pkg="$1"
    dpkg -s "$pkg" 2>/dev/null | grep ^Status | grep -q installed
}
function confirm_sudo() {
    # if ! is_root; then
    #     log_error "needs root permission to run.exiting..."
    #     exit 1
    # fi
    local target="sudo"
    if ! is_pkg_installed "apt-utils"; then
        log_info "apt-utils is not available ... installing now"
        apt-get -qq update &&
            DEBIAN_FRONTEND=noninteractive apt-get install -qqy apt-utils
    fi
    if ! has_sudo; then
        log_info "sudo is not available ... installing now"
        apt-get -qq update &&
            DEBIAN_FRONTEND=noninteractive apt-get install -qqy "$target"
    fi
}
function arch_probe(){
    echo $(uname -m)
}
function os_name(){
    echo "$(uname -s | tr "[:upper:]" "[:lower:]")" 
}
function min_bash_version() {
    local -r ver="$1"
	[ "${BASH_VERSINFO:-0}" -ge $((ver)) ]
}
function get_debian_codename() {
    local -r os_release=$(cat /etc/os-release)
    local -r version_codename_line=$(echo "$os_release" | grep -e VERSION_CODENAME)
    local -r result=$(string_strip_prefix "$version_codename_line" "VERSION_CODENAME=")
    echo "$result"
}
function get_distro_name() {
    local -r os_release=$(cat /etc/os-release)
    local -r trimmed=$(echo "$os_release" | grep -v VERSION_ID | grep -v ID_LIKE)
    local -r version_codename_line=$(echo "$trimmed" | grep -e ID)
    local -r result=$(string_strip_prefix "$version_codename_line" "ID=")
    echo "$result"
}
function add_key() {
    if ! is_root; then
        log_error "needs root permission to run.exiting..."
        exit 1
    fi
    if [[ $# == 0 ]]; then
        log_error "No argument was passed to add_key method"
        exit 1
    fi
   
    curl -fsSL "$1" | sudo apt-key add -
}
function add_repo() {
    if ! is_root; then
        log_error "needs root permission to run.exiting..."
        exit 1
    fi
    if [[ $# != 2 ]]; then
        echo
        echo "desc : adds an apt repository"
        echo
        echo "method usage: add_repo [name] [address]"
        echo
        exit 1
    fi
    local -r dest="/etc/apt/sources.list.d/$1.list"
    local -r addr="$2"
    if file_exists "$dest"; then
        log_warn "a repo source for $1 already exists. deleting the existing one..."
        rm "$dest"
    fi
    log_info "adding repo for $1"
    echo "$addr" | sudo tee "$dest"
    sudo apt-get update
}
function apt_cleanup() {
    if ! is_root; then
        log_error "needs root permission to run.exiting..."
        exit 1
    fi
    confirm_sudo
    local -r download_list="/tmp/apt-fast.list"
    if file_exists "$download_list"; then
        sudo apt-get install -y --fix-broken
        rm "$download_list"
    fi
    sudo apt-get clean
    sudo rm -rf /var/cache/apt/archives/*
}

function filter_installed() {
    local -r deps=("$@")
    local -r raw_list=$(dpkg -s ${deps[@]} 2>&1)
    local -r filtered=$(echo "${raw_list}" | grep -E "dpkg-query: package")
    local -r trimmed=$(echo "${filtered}" | sed -n "s,[^']*'\([^']*\).*,\1,p")
    echo "$trimmed"
}
function assert_is_installed() {
    local -r name="$1"
    if ! os_command_is_available "$name"; then
        log_error "'$name' is required but cannot be found in the system's PATH."
        exit 1
    fi
}
function user_exists() {
    local -r user="$1"
    getent passwd ${user}  > /dev/null
}
function new_user_as_sudo() {
    if ! is_root; then
        log_error "needs root permission to run.exiting..."
        exit 1
    fi
    if [[ $# == 0 ]]; then
        log_error "No argument was passed to new_user_as_sudo method"
        exit 1
    fi
    local -r user="$1"
    if ! $(user_exists "${user}");then
        log_info "creating user ${user}"
        sudo useradd -l -u 33333 -G sudo \
        -md "/home/${user}" \
        -s  /bin/bash -p "${user}" "${user}" 
    fi
}
function execute_as_sudo {
        local firstArg=$1
        if [ $(type -t $firstArg) = function ]
        then
                shift && command sudo bash -c "$(declare -f $firstArg);$firstArg $*"
        elif [ $(type -t $firstArg) = alias ]
        then
                alias sudo='\sudo '
                eval "sudo $@"
        else
                command sudo "$@"
        fi
}

export -f is_root
export -f os_command_is_available
export -f has_sudo
export -f has_apt
export -f has_parallel
export -f is_pkg_installed
export -f confirm_sudo
export -f get_debian_codename
export -f add_key
export -f add_repo
export -f apt_cleanup
export -f filter_installed
export -f assert_is_installed
export -f min_bash_version
export -f arch_probe
export -f user_exists
export -f new_user_as_sudo
export -f os_name
export -f get_distro_name
export -f execute_as_sudo
