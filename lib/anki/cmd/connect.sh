#!/usr/bin/env bash

anki_cmd_connect() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki connect <ping|url|call>"
    shift || true

    case "$subcmd" in
        ping)
            [ "$#" -eq 0 ] || ankic_die "usage: anki connect ping"
            local version_result
            version_result=$(ankic_invoke version '{}')
            printf 'reachable, version %s\n' "$(ankic_print_scalar "$version_result")"
            ;;
        url)
            [ "$#" -eq 0 ] || ankic_die "usage: anki connect url"
            ankic_url
            ;;
        call)
            [ "$#" -ge 1 ] || ankic_die "usage: anki connect call <action> [params-json]"
            ankic_invoke "$1" "${2:-'{}'}"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki connect ping
  anki connect url
  anki connect call <action> [params-json]
EOF
            ;;
        *)
            ankic_die "unknown connect command: $subcmd"
            ;;
    esac
}
