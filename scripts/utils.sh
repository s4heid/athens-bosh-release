#!/usr/bin/env bash

set -eu

function is-installed() {
    if ! command -v "$1" > /dev/null 2>&1 ; then
        >&2 echo "ERROR: $1 must be installed"
        exit 1
    fi
}

function logged-in() {
    if ! lpass status -q ; then
        >&2 echo "ERROR: not logged in to LastPass. Run 'lpass login'"
        exit 1
    fi
}