#!/usr/bin/env bash
# shellcheck source=./lib/os/os.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/os/os.sh"

function fast_apt() {
    if ! is_root; then
        log_error "fast_apt needs root permission to run.exiting..."
        exit 1
    fi
    if ! os_command_is_available "aria2c"; then
        log_info "aria2 not available.installing aria2 ..."
        apt-get install -yqq aria2
    fi
    if ! os_command_is_available "curl"; then
        log_info "curl not available.installing curl ..."
        apt-get install -yqq curl
    fi
    if echo "$@" | grep -q "upgrade\|install\|dist-upgrade"; then
        local -r download_list="/tmp/apt-fast.list"
        local -r apt_cache="/var/cache/apt/archives"
        local -r command="${1}"
        shift
        local -r uris=$(apt-get -y --print-uris $command "${@}")
        local -r urls=($(echo ${uris} | grep -o -E "(ht|f)t(p|ps)://[^\']+" ))
        for link in ${urls[@]}; do
            log_info "adding ${link} to download candidates"
            echo "$link" >>"$download_list"
            echo " dir=$apt_cache" >>"$download_list"
        done
        if  file_exists "$download_list"; then
            downloader "$download_list"
            sudo apt-get $command -y "$@" 
            log_info "cleaning up apt cache ..."
            apt_cleanup
        else
            log_warn "there are no install candidates at $download_list "
            log_info "cleaning up apt cache ..."
            apt_cleanup
        fi
    else
        sudo apt-get "$@"
    fi
}
export -f fast_apt
