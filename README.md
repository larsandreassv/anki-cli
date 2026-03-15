# anki

Small shell-first commands for working with Anki resources through AnkiConnect.

This repo now contains only the core CLI:

- `anki`: the base command for decks, models, notes, and AnkiConnect diagnostics

The old `anki-jp` study-specific workflow is no longer part of this repo. It should live in a separate repository and call the installed `anki` command.

## Design goals

- resource-oriented commands
- small files with one clear job
- shell-first implementation
- direct access to raw AnkiConnect actions when needed

## Requirements

- `bash`
- `curl`
- `python3`
- Anki running locally with the AnkiConnect add-on enabled

## Install for a user account

From this repository:

```sh
./install.sh
```

Make sure `~/.local/bin` is on your `PATH`.

If you want a custom prefix:

```sh
BIN_DIR="$HOME/bin" DATA_DIR="$HOME/.local/share/anki" ./install.sh
```

If you use a custom `DATA_DIR`, also export:

```sh
export ANKI_DATA_DIR="$HOME/.local/share/anki"
```

## Command structure

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

### Top-level commands

- `anki doctor`
- `anki version`

### Connect commands

- `anki connect ping`
- `anki connect url`
- `anki connect call <action> [params-json]`

### Deck commands

- `anki deck list`

### Model commands

- `anki model list`
- `anki model fields <model>`

### Note commands

- `anki note check ...`
- `anki note add ...`

`anki note add` checks `canAddNotes` first and fails before adding when AnkiConnect reports that the note cannot be added.

## File layout

The CLI is split into small command-family scripts:

- `bin/anki`
- `lib/anki/common.sh`
- `lib/anki/cmd/doctor.sh`
- `lib/anki/cmd/connect.sh`
- `lib/anki/cmd/deck.sh`
- `lib/anki/cmd/model.sh`
- `lib/anki/cmd/note.sh`
- `lib/anki/cmd/version.sh`

## Environment

- `ANKI_DATA_DIR`: override where the `anki` binary looks for its installed library files
- `ANKI_CONNECT_URL`: override the AnkiConnect endpoint, default `http://127.0.0.1:8765`
- `ANKI_CONNECT_API_KEY`: optional API key if AnkiConnect authentication is enabled

## Error handling

The commands fail clearly when:

- Anki is not running
- AnkiConnect is not reachable
- the deck or model does not exist
- the configured field names do not exist
- a note cannot be added because it is rejected or appears to be a duplicate

## Troubleshooting AnkiConnect

If commands cannot connect:

```sh
anki doctor
```

Then check:

- Anki desktop is running
- the AnkiConnect add-on is installed and enabled
- the add-on code is `2055492159`
- you restarted Anki after installing or enabling the add-on
- visiting `http://127.0.0.1:8765` in a browser shows `Anki-Connect`
- if you use AnkiConnect authentication, `ANKI_CONNECT_API_KEY` is set correctly

### WSL

If `anki` runs inside WSL but Anki runs on Windows, `127.0.0.1` in WSL may not reach Windows Anki.

Run:

```sh
anki doctor
```

To update AnkiConnect's Windows config automatically from WSL:

```sh
anki doctor --fix-wsl
```

If needed, point the CLI at the Windows host:

```sh
export ANKI_CONNECT_URL=http://<windows-host-ip>:8765
```

`anki doctor` prefers the WSL default gateway as the Windows host candidate. Some WSL setups expose a DNS-only address such as the `/etc/resolv.conf` nameserver, which is not a usable host IP for AnkiConnect.

Also note that opening `http://127.0.0.1:8765` in a browser on Windows only proves that Windows can reach AnkiConnect. It does not prove that WSL can.

`anki doctor --fix-wsl` updates AnkiConnect's `config.json`, creates a `.bak` backup alongside it, and sets `webBindAddress` to `0.0.0.0`.

If Windows can reach `127.0.0.1:8765` but WSL still cannot, AnkiConnect is likely listening only on Windows localhost. In that case, run `anki doctor --fix-wsl`, restart Anki, and retry.

## Migration notes

- The binary is now `anki`, not `anki-cli`.
- The old flat commands are gone in favor of resource-oriented subcommands.
- The old bundled `anki-jp` script has been removed from this repo.
