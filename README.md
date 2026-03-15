# anki

Small shell-first commands for working with Anki resources through AnkiConnect.

![Terminal demo](assets/anki-demo.gif)

_Regenerate with `./scripts/render-demo.sh`. For future demos, prefer VHS over Terminalizer if you want a cleaner dedicated workflow._

## Install

```sh
./install.sh
```

If you use a custom install path:

```sh
BIN_DIR="$HOME/bin" DATA_DIR="$HOME/.local/share/anki" ./install.sh
export ANKI_DATA_DIR="$HOME/.local/share/anki"
```

## Commands

```sh
anki doctor
anki doctor --fix-wsl
anki version
anki connect ping
anki connect url
anki connect call findNotes '{"query":"deck:Japanese::RTK"}'
anki deck list
anki model list
anki model fields RTK
anki note check --deck "Japanese::RTK" --model RTK --field Keyword=festival --field Kanji=祭
anki note add --deck "Japanese::RTK" --model RTK --field Keyword=festival --field Kanji=祭
```

## Environment

- `ANKI_DATA_DIR`: override where `anki` looks for installed library files
- `ANKI_CONNECT_URL`: override the AnkiConnect endpoint
- `ANKI_CONNECT_API_KEY`: optional AnkiConnect API key

## WSL

If Anki runs on Windows and `anki` runs inside WSL:

```sh
anki doctor
anki doctor --fix-wsl
anki deck list
```

`anki doctor --fix-wsl` updates AnkiConnect's Windows `config.json`, creates a `.bak` backup, and sets `webBindAddress` to `0.0.0.0`.

When `ANKI_CONNECT_URL` is not set, commands running inside WSL will try the default `http://127.0.0.1:8765` first and then automatically retry the suggested Windows host URL.

You can still set `ANKI_CONNECT_URL` explicitly if you want to force a specific endpoint.
