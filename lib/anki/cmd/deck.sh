#!/usr/bin/env bash

anki_cmd_deck() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki deck list"
    shift || true

    case "$subcmd" in
        list)
            [ "$#" -eq 0 ] || ankic_die "usage: anki deck list"
            local deck_names
            deck_names=$(ankic_invoke deckNames '{}') || return 1
            ankic_print_json_lines "$deck_names"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki deck list
EOF
            ;;
        *)
            ankic_die "unknown deck command: $subcmd"
            ;;
    esac
}
