#!/bin/bash
set -euo pipefail
APP="$1"
PORT="$2"
SHOT="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${4:-check}"
xattr -cr "$APP" || true
open "$APP"
if [[ "$MODE" == "desk" ]]; then
  alive=1
else
alive=0
for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${PORT}/api/v1/health" >/dev/null; then
    alive=1
    break
  fi
  sleep 1
done
if [[ "$alive" != 1 ]]; then
  echo "server on port ${PORT} did not answer"
  exit 1
fi
HEALTH="$(curl -fsS "http://127.0.0.1:${PORT}/api/v1/health")"
echo "$HEALTH"
if [[ "$MODE" == "demo" ]]; then
  if ! printf '%s\n' "$HEALTH" | grep -q '"demo":true'; then
    echo "demo app is not talking to the demo server"
    exit 1
  fi
  if ! printf '%s\n' "$HEALTH" | grep -q '"licensed":true'; then
    echo "demo server is still locked"
    exit 1
  fi
fi
fi
sleep 5
if ! pgrep -x schooldesk >/dev/null; then
  echo "schooldesk process is not running"
  exit 1
fi
WID=""
for _ in $(seq 1 10); do
  WID="$(swift -e 'import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in info {
  let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
  if owner.lowercased().contains("school") {
    print(w[kCGWindowNumber as String] ?? "")
    break
  }
}')" || true
  WID="$(printf '%s' "$WID" | tr -d '[:space:]')"
  if [[ -n "$WID" ]]; then
    break
  fi
  sleep 1
done
mkdir -p "$(dirname "$SHOT")"
if [[ -n "$WID" ]]; then
  screencapture -x -l "$WID" "$SHOT"
else
  echo "SchoolDesk window was not found"
  exit 1
fi
BMP="${SHOT%.png}.bmp"
sips -s format bmp "$SHOT" --out "$BMP" >/dev/null
python3 "$ROOT/scripts/not_blank.py" "$BMP"
MODE="${4:-check}"
TEXT="$(swift "$ROOT/scripts/mac_ui.swift" ocr "$SHOT")"
printf '%s\n' "$TEXT"
if [[ "$MODE" == "desk" || "$MODE" == "demo" ]]; then
  if printf '%s\n' "$TEXT" | grep -q "Unlock"; then
    echo "demo showed the unlock screen"
    exit 1
  fi
  if [[ "$MODE" == "desk" ]]; then
    for _ in $(seq 1 20); do
      if printf '%s\n' "$TEXT" | grep -q "Choose who you are"; then
        break
      fi
      sleep 1
      screencapture -x -l "$WID" "$SHOT" || true
      TEXT="$(swift "$ROOT/scripts/mac_ui.swift" ocr "$SHOT" || true)"
    done
    if ! printf '%s\n' "$TEXT" | grep -q "Choose who you are"; then
      echo "demo did not open on the role screen"
      printf '%s\n' "$TEXT"
      exit 1
    fi
  elif ! printf '%s\n' "$TEXT" | grep -q "Sign in"; then
    echo "demo did not show the sign-in screen"
    exit 1
  fi
  killall schooldesk || true
  sleep 2
  SCHOOLDESK_SMOKE=admin "$APP/Contents/MacOS/schooldesk" >/tmp/schooldesk-smoke.log 2>&1 &
  HOME_SHOT="${SHOT%.png}-home.png"
  HOME_TEXT=""
  for _ in $(seq 1 25); do
    sleep 1
    WID="$(swift -e 'import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in info {
  let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
  if owner.lowercased().contains("school") {
    print(w[kCGWindowNumber as String] ?? "")
    break
  }
}')" || true
    WID="$(printf '%s' "$WID" | tr -d '[:space:]')"
    if [[ -z "$WID" ]]; then
      continue
    fi
    screencapture -x -l "$WID" "$HOME_SHOT" || true
    if [[ ! -f "$HOME_SHOT" ]]; then
      continue
    fi
    HOME_TEXT="$(swift "$ROOT/scripts/mac_ui.swift" ocr "$HOME_SHOT" || true)"
    if printf '%s\n' "$HOME_TEXT" | grep -q "Unlock"; then
      echo "unlock screen appeared after sign-in"
      printf '%s\n' "$HOME_TEXT"
      exit 1
    fi
    if printf '%s\n' "$HOME_TEXT" | grep -q "See fees"; then
      break
    fi
  done
  printf '%s\n' "$HOME_TEXT"
  HOME_BMP="${HOME_SHOT%.png}.bmp"
  sips -s format bmp "$HOME_SHOT" --out "$HOME_BMP" >/dev/null
  python3 "$ROOT/scripts/not_blank.py" "$HOME_BMP"
  if printf '%s\n' "$HOME_TEXT" | grep -q "Unlock"; then
    echo "unlock screen appeared after sign-in"
    exit 1
  fi
  if ! printf '%s\n' "$HOME_TEXT" | grep -q "See fees"; then
    echo "admin home did not appear"
    exit 1
  fi
fi
if [[ "$MODE" == "prod" ]]; then
  HEALTH="$(curl -fsS "http://127.0.0.1:${PORT}/api/v1/health")"
  if printf '%s\n' "$HEALTH" | grep -q '"demo":true'; then
    echo "production server is the demo build"
    exit 1
  fi
fi
killall schooldesk || true
echo "smoke ok: $SHOT"
