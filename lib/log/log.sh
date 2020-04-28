#!/usr/bin/env bash
# shellcheck source=./lib/env/env.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/env/env.sh"
# shellcheck source=./lib/string/string.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/string/string.sh"
function log() {
    local -r level="$1"
    local -r message="$2"
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local -r script_name="$(basename "$0")"
    local color
    case "$level" in
    INFO)
        color="string_green"
        ;;
    WARN)
        color="string_yellow"
        ;;
    ERROR)
        color="string_red"
        ;;
    esac
    # echo >&2 -e "$(string_colorify "${color}" "${timestamp} [${level}] ==>") $(string_blue "[$script_name]") ${message}"
    echo >&2 -e "$(${color} "${timestamp} [${level}] ==>") $(string_blue "[$script_name]") ${message}"
}
function log_info() {
    local -r message="$1"
    log "INFO" "$message"
}
function log_warn() {
    local -r message="$1"
    log "WARN" "$message"
}
function log_error() {
    local -r message="$1"
    log "ERROR" "$message"
}
export -f log
export -f log_info
export -f log_warn
export -f log_error
