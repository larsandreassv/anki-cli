#!/usr/bin/env bash
set -euo pipefail
cd /home/larsandreas/repos/anki-cli
export ANKI_CONNECT_URL=http://127.0.0.1:8766
run_cmd() {
  printf '\n$ %s\n' "$*"
  "$@"
  sleep 0.8
}
run_cmd ./bin/anki connect ping
run_cmd ./bin/anki deck list
run_cmd ./bin/anki model fields RTK
run_cmd ./bin/anki note add --deck Japanese::RTK --model RTK --field Keyword=festival --field Kanji=祭
run_cmd ./bin/anki connect call findNotes '{"query":"deck:Japanese::RTK"}'
