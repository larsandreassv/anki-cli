#!/usr/bin/env bash

anki_cmd_doctor() {
    case "${1:-}" in
        '')
            anki_run_doctor false
            ;;
        --fix-wsl)
            [ "$#" -eq 1 ] || ankic_die "usage: anki doctor [--fix-wsl]"
            anki_run_doctor true
            ;;
        --help|-h|help)
            cat <<'EOF'
Usage:
  anki doctor [--fix-wsl]
EOF
            ;;
        *)
            ankic_die "usage: anki doctor [--fix-wsl]"
            ;;
    esac
}

anki_run_doctor() {
    local apply_wsl_fix=${1:-false}
    local url body version_result config_update
    local wsl_url=''

    url=$(ankic_url)
    printf 'AnkiConnect URL: %s\n' "$url"

    if ankic_is_wsl; then
        printf 'Environment: WSL detected\n'
        wsl_url=$(ankic_wsl_suggested_url || true)
        if [ -n "$wsl_url" ]; then
            printf 'Suggested Windows host URL: %s\n' "$wsl_url"
        fi
        if [ "$apply_wsl_fix" = 'true' ]; then
            printf 'Applying WSL-friendly AnkiConnect config...\n'
            config_update=$(ankic_configure_windows_ankiconnect_for_wsl)
            printf '%s\n' "$config_update"
            printf 'Restart Anki on Windows for the new bind address to take effect.\n'
            if [ -n "$wsl_url" ]; then
                printf 'Then use this in your shell:\n'
                printf '  export ANKI_CONNECT_URL=%s\n' "$wsl_url"
            fi
            return 0
        fi
    elif [ "$apply_wsl_fix" = 'true' ]; then
        ankic_die "doctor --fix-wsl is only supported inside WSL"
    fi

    if body=$(curl --silent --show-error --connect-timeout 2 --max-time 5 "$url" 2>/dev/null); then
        if [ "$body" = "AnkiConnect" ] || [ "$body" = "Anki-Connect" ] || printf '%s' "$body" | grep -q '"apiVersion"'; then
            printf 'HTTP probe: reachable (%s)\n' "$body"
        else
            printf 'HTTP probe: reachable, unexpected body: %s\n' "$body"
        fi
    else
        printf 'HTTP probe: failed to connect\n'
    fi

    if version_result=$(ankic_invoke version '{}' 2>/dev/null); then
        printf 'API probe: reachable, version %s\n' "$(ankic_print_scalar "$version_result")"
        return 0
    fi

    if [ -n "$wsl_url" ] && [ "$url" != "$wsl_url" ]; then
        printf '\n'
        printf 'Trying suggested Windows host URL...\n'
        if body=$(ANKI_CONNECT_URL="$wsl_url" curl --silent --show-error --connect-timeout 2 --max-time 5 "$wsl_url" 2>/dev/null); then
            printf 'Windows host HTTP probe: reachable (%s)\n' "$body"
            if version_result=$(ANKI_CONNECT_URL="$wsl_url" ankic_invoke version '{}' 2>/dev/null); then
                printf 'Windows host API probe: reachable, version %s\n' "$(ankic_print_scalar "$version_result")"
                printf '\n'
                printf 'Use this in your shell:\n'
                printf '  export ANKI_CONNECT_URL=%s\n' "$wsl_url"
                return 0
            fi
        else
            printf 'Windows host HTTP probe: failed to connect\n'
        fi
    fi

    if ankic_is_wsl; then
        printf '\n'
        printf 'WSL diagnosis: if Windows can open http://127.0.0.1:8765 but WSL cannot,\n'
        printf 'AnkiConnect is likely bound only to Windows localhost. In that case, set\n'
        printf 'AnkiConnect "webBindAddress" to "0.0.0.0", restart Anki, and retry.\n'
    fi

    printf '\n'
    ankic_connection_help
    return 1
}
