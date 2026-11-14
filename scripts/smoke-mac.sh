#!/bin/bash
set -euo pipefail
APP="$1"
PORT="$2"
SHOT="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xattr -cr "$APP" || true
open "$APP"
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
killall schooldesk || true
echo "smoke ok: $SHOT"
