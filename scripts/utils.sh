#!/usr/bin/env bash

set -eu

function info { printf "\n\033[00;34m[$(date +"%r")] INFO: $1\033[0m\n" ;}
function fail { >&2 printf "\n\033[2K\033[0;31m[$(date +"%r")] ERROR: $1\033[0m\n"; exit 1 ;}

function is-installed {
    if ! command -v "$1" > /dev/null 2>&1 ; then
        fail "$1 must be installed"
    fi
}

function logged-in {
    if ! lpass status -q ; then
        fail "not logged in to LastPass. Try running 'lpass login'"
    fi
}