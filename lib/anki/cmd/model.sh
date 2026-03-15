#!/usr/bin/env bash

anki_cmd_model() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki model <list|fields>"
    shift || true

    case "$subcmd" in
        list)
            [ "$#" -eq 0 ] || ankic_die "usage: anki model list"
            local model_names
            model_names=$(ankic_invoke modelNames '{}') || return 1
            ankic_print_json_lines "$model_names"
            ;;
        fields)
            [ "$#" -eq 1 ] || ankic_die "usage: anki model fields <model>"
            local model_fields
            model_fields=$(ankic_invoke modelFieldNames "$(ankic_make_named_params_json modelName "$1")") || return 1
            ankic_print_json_lines "$model_fields"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki model list
  anki model fields <model>
EOF
            ;;
        *)
            ankic_die "unknown model command: $subcmd"
            ;;
    esac
}
