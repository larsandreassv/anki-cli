#!/usr/bin/env bash

anki_cmd_version() {
    [ "$#" -eq 0 ] || ankic_die "usage: anki version"
    local version_result
    version_result=$(ankic_invoke version '{}') || return 1
    ankic_print_scalar "$version_result"
}
