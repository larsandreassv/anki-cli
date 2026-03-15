#!/usr/bin/env bash

ankic_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

ankic_require_command() {
    command -v "$1" >/dev/null 2>&1 || ankic_die "required command not found: $1"
}

ankic_url() {
    printf '%s\n' "${ANKI_CONNECT_URL:-http://127.0.0.1:8765}"
}

ankic_should_try_wsl_fallback() {
    [ -z "${ANKI_CONNECT_URL:-}" ] || return 1
    ankic_is_wsl || return 1
    [ "$(ankic_url)" = 'http://127.0.0.1:8765' ]
}

ankic_is_wsl() {
    [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version
}

ankic_wsl_windows_gateway() {
    command -v ip >/dev/null 2>&1 || return 1
    ip route 2>/dev/null | awk '/^default/ { print $3; exit }'
}

ankic_wsl_windows_host() {
    local host

    host=$(ankic_wsl_windows_gateway || true)
    if [ -n "$host" ]; then
        printf '%s\n' "$host"
        return 0
    fi

    [ -r /etc/resolv.conf ] || return 1
    awk '/^nameserver / { print $2; exit }' /etc/resolv.conf
}

ankic_wsl_suggested_url() {
    local host
    host=$(ankic_wsl_windows_host) || return 1
    [ -n "$host" ] || return 1
    printf 'http://%s:8765\n' "$host"
}

ankic_windows_ankiconnect_config_path() {
    ankic_require_command powershell.exe
    ankic_require_command wslpath

    local windows_path
    windows_path=$(powershell.exe -NoProfile -Command '[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; $path = Join-Path $env:APPDATA "Anki2\\addons21\\2055492159\\config.json"; if (Test-Path $path) { Write-Output $path } else { exit 1 }' 2>/dev/null | tr -d '\r') || return 1
    [ -n "$windows_path" ] || return 1
    wslpath -u "$windows_path"
}

ankic_configure_windows_ankiconnect_for_wsl() {
    ankic_is_wsl || ankic_die "doctor --fix-wsl is only supported inside WSL"

    local config_path backup_path backup_status
    config_path=$(ankic_windows_ankiconnect_config_path) || ankic_die "unable to locate AnkiConnect config.json on Windows; make sure AnkiConnect is installed"
    backup_path="${config_path}.bak"
    backup_status='existing'

    if [ ! -f "$backup_path" ]; then
        cp "$config_path" "$backup_path" || ankic_die "failed to create backup: $backup_path"
        backup_status='created'
    fi

    ankic_python_json - "$config_path" "$backup_path" "$backup_status" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
backup_path = Path(sys.argv[2])
backup_status = sys.argv[3]

with config_path.open(encoding="utf-8") as fh:
    config = json.load(fh)

old_bind = config.get("webBindAddress")
new_bind = "0.0.0.0"
changed = old_bind != new_bind
config["webBindAddress"] = new_bind

with config_path.open("w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=4)
    fh.write("\n")

old_display = "<unset>" if old_bind is None else str(old_bind)
status = "changed" if changed else "unchanged"
print(f"Status: {status}")
print(f"Config path: {config_path}")
print(f"Backup path: {backup_path} ({backup_status})")
print(f"webBindAddress: {old_display} -> {config['webBindAddress']}")
PY
}

ankic_connection_help() {
    cat >&2 <<EOF
AnkiConnect is not reachable at $(ankic_url).

Try this:
  1. Start the Anki desktop app.
  2. Install the AnkiConnect add-on if you have not already:
     add-on code: 2055492159
  3. Restart Anki after installing or enabling the add-on.
  4. Open $(ankic_url) in your browser.
     A working AnkiConnect server usually responds with: Anki-Connect
  5. If you configured an API key in AnkiConnect, export ANKI_CONNECT_API_KEY.

You can also run:
  anki doctor
EOF

    if ankic_is_wsl; then
        local suggested_url
        suggested_url=$(ankic_wsl_suggested_url || true)
        cat >&2 <<EOF

WSL note:
  This shell is running inside WSL. Windows localhost forwarding is not guaranteed,
  so a browser working on Windows does not prove the URL is reachable from WSL.
  If Anki is running on Windows, try this from WSL:
EOF
        if [ -n "$suggested_url" ]; then
            cat >&2 <<EOF
    export ANKI_CONNECT_URL=$suggested_url
    anki doctor
EOF
        else
            cat >&2 <<'EOF'
    export ANKI_CONNECT_URL=http://<windows-host-ip>:8765
    anki doctor
EOF
        fi
        cat >&2 <<'EOF'

  To update AnkiConnect's Windows config automatically, run:
    anki doctor --fix-wsl

  You may also need to set AnkiConnect's "webBindAddress" to "0.0.0.0" and restart Anki.
  If Windows can open http://127.0.0.1:8765 but WSL curl still fails, AnkiConnect is
  probably listening only on Windows localhost.
EOF
    fi
}

ankic_python_json() {
    ankic_require_command python3
    python3 "$@"
}

ankic_make_named_params_json() {
    ankic_python_json - "$1" "$2" <<'PY'
import json
import sys

print(json.dumps({sys.argv[1]: sys.argv[2]}, ensure_ascii=False))
PY
}

ankic_make_note_param_json() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

print(json.dumps({"note": json.loads(sys.argv[1])}, ensure_ascii=False))
PY
}

ankic_wrap_single_note_params() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

print(json.dumps({"notes": [json.loads(sys.argv[1])]}, ensure_ascii=False))
PY
}

ankic_build_note_json() {
    ankic_python_json - "$@" <<'PY'
import json
import sys

if len(sys.argv) < 5:
    raise SystemExit("invalid note payload")

deck = sys.argv[1]
model = sys.argv[2]
allow_duplicate = sys.argv[3].lower() == "true"
fields = {}

for field_spec in sys.argv[4:]:
    if "=" not in field_spec:
        raise SystemExit(f"invalid field, expected name=value: {field_spec}")
    name, value = field_spec.split("=", 1)
    if not name:
        raise SystemExit(f"field name cannot be empty: {field_spec}")
    fields[name] = value

note = {
    "deckName": deck,
    "modelName": model,
    "fields": fields,
    "options": {"allowDuplicate": allow_duplicate},
}

print(json.dumps(note, ensure_ascii=False))
PY
}

ankic_request_payload() {
    ankic_python_json - "$1" "$2" <<'PY'
import json
import os
import sys

action = sys.argv[1]
params = json.loads(sys.argv[2])
payload = {"action": action, "version": 6, "params": params}
api_key = os.environ.get("ANKI_CONNECT_API_KEY")
if api_key:
    payload["key"] = api_key

print(json.dumps(payload, ensure_ascii=False))
PY
}

ankic_post_payload() {
    local url=$1
    local payload=$2

    curl --silent --show-error \
        --connect-timeout 2 \
        --max-time 10 \
        -H 'Content-Type: application/json' \
        --data-binary "$payload" \
        "$url"
}

ankic_extract_result() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

try:
    response = json.loads(sys.argv[1])
except json.JSONDecodeError as exc:
    raise SystemExit(f"invalid JSON response from AnkiConnect: {exc}")

if not isinstance(response, dict):
    raise SystemExit("unexpected response from AnkiConnect")

if "error" not in response or "result" not in response:
    raise SystemExit("malformed response from AnkiConnect")

if response["error"] is not None:
    raise SystemExit(str(response["error"]))

print(json.dumps(response["result"], ensure_ascii=False))
PY
}

ankic_invoke() {
    ankic_require_command curl
    ankic_require_command python3

    local action=$1
    local params_json=${2:-'{}'}
    local url
    local fallback_url=''
    local payload
    local response

    if ! payload=$(ankic_request_payload "$action" "$params_json"); then
        printf 'error: failed to build request payload for action: %s\n' "$action" >&2
        return 1
    fi

    url=$(ankic_url)
    if ankic_should_try_wsl_fallback; then
        fallback_url=$(ankic_wsl_suggested_url || true)
    fi

    if ! response=$(ankic_post_payload "$url" "$payload" 2>/dev/null); then
        if [ -n "$fallback_url" ] && [ "$fallback_url" != "$url" ] && response=$(ankic_post_payload "$fallback_url" "$payload"); then
            :
        else
            ankic_connection_help
            return 1
        fi
    fi

    if [ -z "$response" ]; then
        printf 'error: AnkiConnect returned an empty response\n' >&2
        return 1
    fi

    local result
    if ! result=$(ankic_extract_result "$response" 2>&1); then
        printf 'error: %s\n' "$result" >&2
        return 1
    fi

    printf '%s\n' "$result"
}

ankic_print_scalar() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

value = json.loads(sys.argv[1])
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("null")
else:
    print(value)
PY
}

ankic_print_json_lines() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

value = json.loads(sys.argv[1])
if not isinstance(value, list):
    raise SystemExit("expected a JSON array result")
for item in value:
    if isinstance(item, (dict, list)):
        print(json.dumps(item, ensure_ascii=False))
    elif item is None:
        print("null")
    elif isinstance(item, bool):
        print("true" if item else "false")
    else:
        print(item)
PY
}

ankic_print_first_json_value() {
    ankic_python_json - "$1" <<'PY'
import json
import sys

value = json.loads(sys.argv[1])
if not isinstance(value, list) or not value:
    raise SystemExit("expected a non-empty JSON array result")
item = value[0]
if isinstance(item, bool):
    print("true" if item else "false")
elif item is None:
    print("null")
elif isinstance(item, (dict, list)):
    print(json.dumps(item, ensure_ascii=False))
else:
    print(item)
PY
}
