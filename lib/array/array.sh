#!/usr/bin/env bash
# shellcheck source=./lib/env/env.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/env/env.sh"
function array_contains() {
    local -r needle="$1"
    shift
    local -ra haystack=("$@")
    local item
    for item in "${haystack[@]}"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}
# https://stackoverflow.com/a/15988793/2308858
function array_split() {
    local -r separator="$1"
    local -r str="$2"
    local -a ary=()
    IFS="$separator" read -ra ary <<<"$str"
    # echo "${ary[*]}"
    echo "${ary[@]}"
}
function array_join() {
    local -r separator="$1"
    shift
    local -ar values=("$@")
    local out=""
    for ((i = 0; i < "${#values[@]}"; i++)); do
        if [[ "$i" -gt 0 ]]; then
            out="${out}${separator}"
        fi
        out="${out}${values[i]}"
    done
    echo -n "$out"
}
# https://stackoverflow.com/a/13216833/2308858
function array_prepend() {
    local -r prefix="$1"
    shift 1
    local -ar ary=("$@")
    updated_ary=("${ary[@]/#/$prefix}")
    echo "${updated_ary[*]}"
}
export -f array_contains
export -f array_split
export -f array_join
export -f array_prepend
