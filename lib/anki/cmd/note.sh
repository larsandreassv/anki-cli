#!/usr/bin/env bash

anki_cmd_card() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki card <check|add> ..."
    shift || true

    case "$subcmd" in
        check)
            anki_card_parse_args "$@"
            anki_card_can_add
            ;;
        add)
            anki_card_parse_args "$@"
            if [ "$(anki_card_can_add)" != "true" ]; then
                ankic_die "card cannot be added; it may be a duplicate or invalid for the selected deck/cardtype"
            fi
            local add_note_result
            add_note_result=$(ankic_invoke addNote "$(ankic_make_note_param_json "$ANKI_NOTE_JSON")") || return 1
            ankic_print_scalar "$add_note_result"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki card check --deck <deck> --cardtype <cardtype> --field <name> <value> [--field ...] [--allow-duplicate]
  anki card add --deck <deck> --cardtype <cardtype> --field <name> <value> [--field ...] [--allow-duplicate]
EOF
            ;;
        *)
            ankic_die "unknown card command: $subcmd"
            ;;
    esac
}

anki_card_parse_args() {
    local deck=''
    local cardtype=''
    local allow_duplicate='false'
    local fields=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --deck)
                [ "$#" -ge 2 ] || ankic_die "missing value for --deck"
                deck=$2
                shift 2
                ;;
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                shift 2
                ;;
            --field)
                [ "$#" -ge 3 ] || ankic_die "missing name/value for --field"
                fields+=("$2" "$3")
                shift 3
                ;;
            --allow-duplicate)
                allow_duplicate='true'
                shift
                ;;
            *)
                ankic_die "unknown option for card command: $1"
                ;;
        esac
    done

    [ -n "$deck" ] || ankic_die "--deck is required"
    [ -n "$cardtype" ] || ankic_die "--cardtype is required"
    [ "${#fields[@]}" -gt 0 ] || ankic_die "at least one --field <name> <value> is required"

    ANKI_NOTE_JSON=$(ankic_build_note_json "$deck" "$cardtype" "$allow_duplicate" "${fields[@]}")
}

anki_card_can_add() {
    local can_add_result
    can_add_result=$(ankic_invoke canAddNotes "$(ankic_wrap_single_note_params "$ANKI_NOTE_JSON")") || return 1
    ankic_print_first_json_value "$can_add_result"
}
