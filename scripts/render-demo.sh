#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

python3 "$ROOT_DIR/assets/terminalizer/render_gif.py"
