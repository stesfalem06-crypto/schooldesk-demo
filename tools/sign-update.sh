#!/bin/sh
# Signs an update bundle. The private key is read from a file path.
# Example:
#   sh tools/sign-update.sh "$HOME/shamm-keys/update.priv" ./payload sms-v2 dist/shamm-update.smsu
set -eu
KEY="${1:-}"
DIR="${2:-}"
VERSION="${3:-sms-v1}"
OUT="${4:-}"
if [ -z "$KEY" ] || [ -z "$DIR" ] || [ -z "$OUT" ]; then
  echo "Use: sh tools/sign-update.sh PRIVATE-KEY-FILE PAYLOAD-FOLDER VERSION OUTPUT.smsu"
  exit 2
fi
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT/server"
go run ./cmd/updatekey -key "$KEY" -dir "$DIR" -version "$VERSION" -schema 2 -out "$OUT"
