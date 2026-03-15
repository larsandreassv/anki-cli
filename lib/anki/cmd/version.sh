#!/usr/bin/env bash

anki_cmd_version() {
    [ "$#" -eq 0 ] || ankic_die "usage: anki version"
    ankic_print_scalar "$(ankic_invoke version '{}')"
}
