#!/usr/bin/env bash
# shellcheck source=./lib/env/env.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/env/env.sh"
# shellcheck source=./lib/log/log.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/log/log.sh"
# shellcheck source=./lib/string/string.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/string/string.sh"
function file_exists() {
    local -r file="$1"
    [[ -f "$file" ]]
}
function get_file_name() {
    local -r target="$1"
    echo "${target##*/}"
}
function get_file_dir() {
    local -r target="$1"
    echo "${target%/*}"
}
function file_exists() {
    local -r file="$1"
    [[ -f "$file" ]]
}
function append_line_to_file() {
    if [[ $# != 2 ]]; then
        echo
        echo "desc : adds a line to a file in case it hasn't already been added "
        echo
        echo "method usage: append_line_to_file [target file] [line]"
        echo
        exit 1
    fi
    local -r dest="$1"
    local -r payload="$2"
    assert_not_empty "file path" "$dest" "needs a file path to work"
    assert_not_empty "line " "$payload" "needs a line to append to file"
    if [[ -z $(grep "$payload" "$dest") ]]; then
        echo "$payload" >>"$dest"
    fi
}
function add_to_bashrc() {
    if [[ $# != 1 ]]; then
        echo
        echo "desc : appends a line to .bashrc in case it hasn't been already added "
        echo
        echo "method usage: add_to_bashrc [line]"
        echo
        exit 1
    fi
    source "$HOME/.bashrc"
    local payload="$1"
    log_info "adding $payload to '$HOME/.bashrc'"
    append_line_to_file "$HOME/.bashrc" "$payload"
    source "$HOME/.bashrc"
}
function add_profile_env_var() {
    if [[ $# != 2 ]]; then
        echo
        echo "desc : adds and exports a variable to .bashrc "
        echo
        echo "method usage: add_profile_env_var [variable name] [variable value]"
        echo
        exit 1
    fi
    local key="$1"
    local value="$2"
    add_to_bashrc "export $key=$value"
}
function add_to_path() {
    if [[ $# != 1 ]]; then
        echo
        echo "desc : adds a directory to path in case it hasn't been already added "
        echo
        echo "method usage: add_to_path [target directory]"
        echo
        exit 1
    fi
    local target_dir="$1"
    add_profile_env_var "PATH" '$PATH':"$target_dir"
}
function downloader() {
    if [[ $# != 1 ]]; then
        echo
        echo "desc : uses aria2 to download links in a file "
        echo
        echo "method usage: downloader [file path containing links]"
        echo
        exit 1
    fi
    local download_list="$1"
    local downloader=""
    downloader="aria2c \
            -j 16 \
            --continue=true \
            --max-connection-per-server=16 \
            --optimize-concurrent-downloads \
            --connect-timeout=600 \
            --timeout=600 \
            --min-split-size=1M \
            --input-file=$download_list"
    $downloader
}
export -f file_exists
export -f get_file_name
export -f get_file_dir
export -f file_exists
export -f append_line_to_file
export -f add_to_bashrc
export -f add_profile_env_var
export -f add_to_path
export -f downloader
