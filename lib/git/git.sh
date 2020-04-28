#!/usr/bin/env bash
# shellcheck source=./lib/os/os.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/os/os.sh"
# shellcheck source=./lib/extract/extract.sh
source "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)/extract/extract.sh"
# package functions
function is_git_available() {
    if ! os_command_is_available "git"; then
        log_error "git is not available. existing..."
        exit 1
    fi
}
function git_undo_commit() {
    is_git_available
    git reset --soft HEAD~
}
function git_reset_local() {
    is_git_available
    git fetch origin
    git reset --hard origin/master
}
function git_pull_latest() {
    is_git_available
    git pull --rebase origin master
}
function git_list_branches() {
    is_git_available
    git branch -a
}
function git_new_branch() {
    is_git_available
    if [[ $# == 1 ]]; then
        echo
        echo "desc : creates a new branch"
        echo
        echo "method usage: git_new_branch <branch name>"
        echo
        exit 1
    fi
    local -r name="$1"
    assert_not_empty "name" "$name" "branch name is needed"
    git checkout -b "$name"
}
function git_repo_size() {
    is_git_available
    # do not show output of git bundle create {>/dev/null 2>&1} ...
    git bundle create .tmp-git-bundle --all >/dev/null 2>&1
    # check for existance of du
    if ! os_command_is_available "du"; then
        log_error "du is not available. existing..."
        exit 1
    fi
    local -r size=$(du -sh .tmp-git-bundle | cut -f1)
    rm .tmp-git-bundle
    echo "$size"
}
function git_user_stats() {
    if [[ $# == 1 ]]; then
        echo
        echo "desc : returns users contributions"
        echo
        echo "method usage: git_user_stats <user name>"
        echo
        exit 1
    fi
    local -r user_name="$1"
    assert_not_empty "user_name" "$user_name" "git username is needed"
    res=$(git log --author="$user_name" --pretty=tformat: --numstat | awk -v GREEN='033[1;32m' -v PLAIN='033[0m' -v RED='033[1;31m' 'BEGIN { add = 0; subs = 0 } { add += $1; subs += $2 } END { printf "Total: %s+%s%s / %s-%s%sn", GREEN, add, PLAIN, RED, subs, PLAIN }')
    echo "$res"
}
function git_clone() {
    is_git_available
    if [[ $# == 0 ]]; then
        echo
        echo "desc : clones and extracts a reposiory lists with aria2"
        echo
        echo "method usage: git_new_branch <branch name>"
        echo
        exit 1
    fi
    local -r repos=("$@")
    local -r download_list="/tmp/git-dl.list"
    if file_exists "${download_list}"; then
        log_warn "existing git candidate download list detected.deleting..."
        rm "$download_list"
    fi
    for repo in "${repos[@]}"; do
        assert_not_empty "repo" "$repo" "repo url cannot be empty"
        name=$(get_file_name "$repo")
        if file_exists "$PWD/$name.zip"; then
            log_warn "an exisitng clone of repositry archive exists.deleting..."
            rm "$PWD/$name.zip"
        fi
        log_info "cloning $repo"
        local -r url="$repo/archive/master.zip"
        echo "${url}" >>"${download_list}"
        echo " dir=$PWD" >>"${download_list}"
        echo " out=$name.zip" >>"${download_list}"
    done
    if file_exists "${download_list}"; then
        downloader "$download_list"
    fi
    for repo in "${repos[@]}"; do
        name=$(get_file_name "$repo")
        if file_exists "$PWD/$name.zip"; then
            extract "$PWD/$name.zip" "$name"
            mv "$PWD/$name/$name-master" "$PWD"
            rm -rf "$PWD/$name/"
            mv "$PWD/$name-master/" "$PWD/$name/"
            rm "$PWD/$name.zip"
        fi
    done
}
function git_release_list() {
    if [[ $# != 2 ]]; then
        echo
        echo "desc : get a repo's releases from"
        echo
        echo "method usage: get_releases_from_git [repo owner] [repo name]"
        echo
        exit 1
    fi
    local -r owner="$1"
    local -r repo="$2"
    local -r reply=$(curl -sL "https://api.github.com/repos/${owner}/${repo}/tags")
    local -r versions=$(echo "${reply}" | jq -r '.[].name')
    local -r sorted=$(echo "${versions}" | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n)
    local -r trimmed=$(echo "${sorted}" | grep -v -E 'beta|master|pre|rc|test')
    echo "$trimmed"
}
function get_latest_release_from_git() {
    if [[ $# != 2 ]]; then
        echo
        echo "desc : gets latest release from git"
        echo
        echo "method usage: get_latest_release_from_git [repo owner] [repo name]"
        echo
        exit 1
    fi
    local -r repo_owner="$1"
    local -r repo_name="$2"
    local -r reply=$(curl -sL https://api.github.com/repos/${repo_owner}/${repo_name}/releases/latest)
    local -r latest=$(echo "$reply" | jq -r '.tag_name')
    echo "$latest"
}
export -f get_latest_release_from_git
export -f is_git_available
export -f git_undo_commit
export -f git_reset_local
export -f git_pull_latest
export -f git_list_branches
export -f git_new_branch
export -f git_repo_size
export -f git_user_stats
export -f git_clone
export -f git_release_list
