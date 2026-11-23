#!/bin/sh
# Writes a new update key into the folder you name.
# Example: sh tools/gen-update-key.sh "$HOME/shamm-keys"
# The private key stays in that folder. Do not commit it.
set -eu
DIR="${1:-}"
if [ -z "$DIR" ]; then
  echo "Name a folder. Example: sh tools/gen-update-key.sh \"\$HOME/shamm-keys\""
  exit 2
fi
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT/server"
go run ./cmd/updatekey -gen "$DIR"
