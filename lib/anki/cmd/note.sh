#!/usr/bin/env bash

anki_cmd_note() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki note <check|add> ..."
    shift || true

    case "$subcmd" in
        check)
            anki_note_parse_args "$@"
            anki_note_can_add
            ;;
        add)
            anki_note_parse_args "$@"
            if [ "$(anki_note_can_add)" != "true" ]; then
                ankic_die "note cannot be added; it may be a duplicate or invalid for the selected deck/model"
            fi
            ankic_print_scalar "$(ankic_invoke addNote "$(ankic_make_note_param_json "$ANKI_NOTE_JSON")")"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki note check --deck <deck> --model <model> --field <name=value> [--field ...] [--allow-duplicate]
  anki note add --deck <deck> --model <model> --field <name=value> [--field ...] [--allow-duplicate]
EOF
            ;;
        *)
            ankic_die "unknown note command: $subcmd"
            ;;
    esac
}

anki_note_parse_args() {
    local deck=''
    local model=''
    local allow_duplicate='false'
    local fields=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --deck)
                [ "$#" -ge 2 ] || ankic_die "missing value for --deck"
                deck=$2
                shift 2
                ;;
            --model)
                [ "$#" -ge 2 ] || ankic_die "missing value for --model"
                model=$2
                shift 2
                ;;
            --field)
                [ "$#" -ge 2 ] || ankic_die "missing value for --field"
                fields+=("$2")
                shift 2
                ;;
            --allow-duplicate)
                allow_duplicate='true'
                shift
                ;;
            *)
                ankic_die "unknown option for note command: $1"
                ;;
        esac
    done

    [ -n "$deck" ] || ankic_die "--deck is required"
    [ -n "$model" ] || ankic_die "--model is required"
    [ "${#fields[@]}" -gt 0 ] || ankic_die "at least one --field name=value is required"

    ANKI_NOTE_JSON=$(ankic_build_note_json "$deck" "$model" "$allow_duplicate" "${fields[@]}")
}

anki_note_can_add() {
    ankic_print_first_json_value "$(ankic_invoke canAddNotes "$(ankic_wrap_single_note_params "$ANKI_NOTE_JSON")")"
}
