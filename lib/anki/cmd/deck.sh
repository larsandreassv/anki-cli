#!/usr/bin/env bash

anki_cmd_deck() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki deck <list|ids|add|stats>"
    shift || true

    case "$subcmd" in
        list)
            [ "$#" -eq 0 ] || ankic_die "usage: anki deck list"
            local deck_names
            deck_names=$(ankic_invoke deckNames '{}') || return 1
            ankic_print_json_lines "$deck_names"
            ;;
        ids)
            [ "$#" -eq 0 ] || ankic_die "usage: anki deck ids"
            local deck_ids
            deck_ids=$(ankic_invoke deckNamesAndIds '{}') || return 1
            ankic_print_json_object_entries "$deck_ids"
            ;;
        add)
            [ "$#" -eq 1 ] || ankic_die "usage: anki deck add <deck>"
            local deck_id
            deck_id=$(ankic_invoke createDeck "$(ankic_make_deck_name_params_json "$1")") || return 1
            ankic_print_scalar "$deck_id"
            ;;
        stats)
            [ "$#" -ge 1 ] || ankic_die "usage: anki deck stats <deck> [<deck> ...]"
            local deck_stats
            deck_stats=$(ankic_invoke getDeckStats "$(ankic_make_named_list_params_json decks "$@")") || return 1
            ankic_print_json_object_entries "$deck_stats"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki deck list
  anki deck ids
  anki deck add <deck>
  anki deck stats <deck> [<deck> ...]
EOF
            ;;
        *)
            ankic_die "unknown deck command: $subcmd"
            ;;
    esac
}
