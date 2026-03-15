#!/usr/bin/env bash

anki_cmd_cardtype() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki cardtype <list|add|fields|templates>"
    shift || true

    case "$subcmd" in
        list)
            [ "$#" -eq 0 ] || ankic_die "usage: anki cardtype list"
            anki_cardtype_list
            ;;
        add)
            anki_cardtype_add "$@"
            ;;
        fields)
            anki_cardtype_fields "$@"
            ;;
        templates)
            anki_cardtype_templates "$@"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki cardtype list
  anki cardtype add --cardtype <cardtype> --field <field> [--field ...] --front <front> --back <back> [--template-name <name>] [--css <css>]
  anki cardtype fields list [--cardtype <cardtype>]
  anki cardtype fields add --cardtype <cardtype> <field>
  anki cardtype fields remove --cardtype <cardtype> <field>
  anki cardtype fields rename --cardtype <cardtype> <old> <new>
  anki cardtype templates list [--cardtype <cardtype>]
  anki cardtype templates add --cardtype <cardtype> --template <name> --front <front> --back <back>
  anki cardtype templates remove --cardtype <cardtype> <template>
  anki cardtype templates rename --cardtype <cardtype> <old> <new>
EOF
            ;;
        *)
            ankic_die "unknown cardtype command: $subcmd"
            ;;
    esac
}

anki_cardtype_list() {
    local model_names
    model_names=$(ankic_invoke modelNames '{}') || return 1
    ankic_print_json_lines "$model_names"
}

anki_cardtype_add() {
    local cardtype=''
    local template_name='Card 1'
    local front=''
    local back=''
    local css=''
    local fields=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                shift 2
                ;;
            --field)
                [ "$#" -ge 2 ] || ankic_die "missing value for --field"
                fields+=("$2")
                shift 2
                ;;
            --template-name)
                [ "$#" -ge 2 ] || ankic_die "missing value for --template-name"
                template_name=$2
                shift 2
                ;;
            --front)
                [ "$#" -ge 2 ] || ankic_die "missing value for --front"
                front=$2
                shift 2
                ;;
            --back)
                [ "$#" -ge 2 ] || ankic_die "missing value for --back"
                back=$2
                shift 2
                ;;
            --css)
                [ "$#" -ge 2 ] || ankic_die "missing value for --css"
                css=$2
                shift 2
                ;;
            *)
                ankic_die "unknown option for cardtype add: $1"
                ;;
        esac
    done

    [ -n "$cardtype" ] || ankic_die "--cardtype is required"
    [ "${#fields[@]}" -gt 0 ] || ankic_die "at least one --field is required"
    [ -n "$front" ] || ankic_die "--front is required"
    [ -n "$back" ] || ankic_die "--back is required"

    ankic_invoke createModel "$(ankic_make_create_model_params_json "$cardtype" "$template_name" "$front" "$back" "$css" "${fields[@]}")" >/dev/null || return 1
    printf '%s\n' "$cardtype"
}

anki_cardtype_fields() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki cardtype fields <list|add|remove|rename> ..."
    shift || true

    case "$subcmd" in
        list)
            anki_cardtype_fields_list "$@"
            ;;
        add)
            anki_cardtype_fields_add "$@"
            ;;
        remove)
            anki_cardtype_fields_remove "$@"
            ;;
        rename)
            anki_cardtype_fields_rename "$@"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki cardtype fields list [--cardtype <cardtype>]
  anki cardtype fields add --cardtype <cardtype> <field>
  anki cardtype fields remove --cardtype <cardtype> <field>
  anki cardtype fields rename --cardtype <cardtype> <old> <new>
EOF
            ;;
        *)
            ankic_die "unknown cardtype fields command: $subcmd"
            ;;
    esac
}

anki_cardtype_fields_list() {
    local cardtype=''

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                shift 2
                ;;
            *)
                ankic_die "unknown option for cardtype fields list: $1"
                ;;
        esac
    done

    if [ -n "$cardtype" ]; then
        anki_cardtype_print_fields "$cardtype"
        return 0
    fi

    local cardtypes=()
    local current_cardtype
    mapfile -t cardtypes < <(anki_cardtype_list)
    for current_cardtype in "${cardtypes[@]}"; do
        while IFS= read -r field_name; do
            printf '%s\t%s\n' "$current_cardtype" "$field_name"
        done < <(anki_cardtype_print_fields "$current_cardtype")
    done
}

anki_cardtype_fields_add() {
    local field_name
    anki_cardtype_parse_required_cardtype "$@" || return 1
    shift $ANKI_CARDTYPE_PARSE_SHIFT
    [ "$#" -eq 1 ] || ankic_die "usage: anki cardtype fields add --cardtype <cardtype> <field>"
    field_name=$1

    ankic_invoke modelFieldAdd "$(ankic_make_model_field_params_json "$ANKI_CARDTYPE_NAME" "$field_name")" >/dev/null || return 1
    printf '%s\n' "$field_name"
}

anki_cardtype_fields_remove() {
    local field_name
    anki_cardtype_parse_required_cardtype "$@" || return 1
    shift $ANKI_CARDTYPE_PARSE_SHIFT
    [ "$#" -eq 1 ] || ankic_die "usage: anki cardtype fields remove --cardtype <cardtype> <field>"
    field_name=$1

    ankic_invoke modelFieldRemove "$(ankic_make_model_field_params_json "$ANKI_CARDTYPE_NAME" "$field_name")" >/dev/null || return 1
    printf '%s\n' "$field_name"
}

anki_cardtype_fields_rename() {
    local old_name new_name
    anki_cardtype_parse_required_cardtype "$@" || return 1
    shift $ANKI_CARDTYPE_PARSE_SHIFT
    [ "$#" -eq 2 ] || ankic_die "usage: anki cardtype fields rename --cardtype <cardtype> <old> <new>"
    old_name=$1
    new_name=$2

    ankic_invoke modelFieldRename "$(ankic_make_model_field_rename_params_json "$ANKI_CARDTYPE_NAME" "$old_name" "$new_name")" >/dev/null || return 1
    printf '%s\n' "$new_name"
}

anki_cardtype_templates() {
    local subcmd=${1:-}
    [ -n "$subcmd" ] || ankic_die "usage: anki cardtype templates <list|add|remove|rename> ..."
    shift || true

    case "$subcmd" in
        list)
            anki_cardtype_templates_list "$@"
            ;;
        add)
            anki_cardtype_templates_add "$@"
            ;;
        remove)
            anki_cardtype_templates_remove "$@"
            ;;
        rename)
            anki_cardtype_templates_rename "$@"
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki cardtype templates list [--cardtype <cardtype>]
  anki cardtype templates add --cardtype <cardtype> --template <name> --front <front> --back <back>
  anki cardtype templates remove --cardtype <cardtype> <template>
  anki cardtype templates rename --cardtype <cardtype> <old> <new>
EOF
            ;;
        *)
            ankic_die "unknown cardtype templates command: $subcmd"
            ;;
    esac
}

anki_cardtype_templates_list() {
    local cardtype=''

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                shift 2
                ;;
            *)
                ankic_die "unknown option for cardtype templates list: $1"
                ;;
        esac
    done

    if [ -n "$cardtype" ]; then
        anki_cardtype_print_templates "$cardtype"
        return 0
    fi

    local cardtypes=()
    local current_cardtype
    mapfile -t cardtypes < <(anki_cardtype_list)
    for current_cardtype in "${cardtypes[@]}"; do
        while IFS= read -r template_name; do
            printf '%s\t%s\n' "$current_cardtype" "$template_name"
        done < <(anki_cardtype_print_templates "$current_cardtype")
    done
}

anki_cardtype_templates_add() {
    local cardtype=''
    local template_name=''
    local front=''
    local back=''

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                shift 2
                ;;
            --template)
                [ "$#" -ge 2 ] || ankic_die "missing value for --template"
                template_name=$2
                shift 2
                ;;
            --front)
                [ "$#" -ge 2 ] || ankic_die "missing value for --front"
                front=$2
                shift 2
                ;;
            --back)
                [ "$#" -ge 2 ] || ankic_die "missing value for --back"
                back=$2
                shift 2
                ;;
            *)
                ankic_die "unknown option for cardtype templates add: $1"
                ;;
        esac
    done

    [ -n "$cardtype" ] || ankic_die "--cardtype is required"
    [ -n "$template_name" ] || ankic_die "--template is required"
    [ -n "$front" ] || ankic_die "--front is required"
    [ -n "$back" ] || ankic_die "--back is required"

    ankic_invoke modelTemplateAdd "$(ankic_make_model_template_add_params_json "$cardtype" "$template_name" "$front" "$back")" >/dev/null || return 1
    printf '%s\n' "$template_name"
}

anki_cardtype_templates_remove() {
    local template_name
    anki_cardtype_parse_required_cardtype "$@" || return 1
    shift $ANKI_CARDTYPE_PARSE_SHIFT
    [ "$#" -eq 1 ] || ankic_die "usage: anki cardtype templates remove --cardtype <cardtype> <template>"
    template_name=$1

    ankic_invoke modelTemplateRemove "$(ankic_make_model_template_params_json "$ANKI_CARDTYPE_NAME" "$template_name")" >/dev/null || return 1
    printf '%s\n' "$template_name"
}

anki_cardtype_templates_rename() {
    local old_name new_name
    anki_cardtype_parse_required_cardtype "$@" || return 1
    shift $ANKI_CARDTYPE_PARSE_SHIFT
    [ "$#" -eq 2 ] || ankic_die "usage: anki cardtype templates rename --cardtype <cardtype> <old> <new>"
    old_name=$1
    new_name=$2

    ankic_invoke modelTemplateRename "$(ankic_make_model_template_rename_params_json "$ANKI_CARDTYPE_NAME" "$old_name" "$new_name")" >/dev/null || return 1
    printf '%s\n' "$new_name"
}

anki_cardtype_print_fields() {
    local cardtype=$1
    local model_fields
    model_fields=$(ankic_invoke modelFieldNames "$(ankic_make_model_name_params_json "$cardtype")") || return 1
    ankic_print_json_lines "$model_fields"
}

anki_cardtype_print_templates() {
    local cardtype=$1
    local model_templates
    model_templates=$(ankic_invoke modelTemplates "$(ankic_make_model_name_params_json "$cardtype")") || return 1
    ankic_print_json_object_keys "$model_templates"
}

anki_cardtype_parse_required_cardtype() {
    local cardtype=''
    local consumed=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --cardtype)
                [ "$#" -ge 2 ] || ankic_die "missing value for --cardtype"
                cardtype=$2
                consumed=$((consumed + 2))
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    [ -n "$cardtype" ] || ankic_die "--cardtype is required"
    ANKI_CARDTYPE_PARSE_SHIFT=$consumed
    ANKI_CARDTYPE_NAME=$cardtype
}
