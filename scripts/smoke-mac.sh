#!/bin/bash
set -euo pipefail
APP="$1"
PORT="$2"
SHOT="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${4:-check}"
# Start from the sample school. A previous run can leave a promoted class in this file.
rm -f "${HOME}/Library/Application Support/SchoolDesk Demo/school.json"
startup_log() {
  echo "---- SchoolDesk startup log ----"
  local log="${HOME}/Library/Logs/SchoolDesk/startup.log"
  if [[ -f "$log" ]]; then
    cat "$log"
  else
    echo "(no startup log at $log)"
  fi
}
trap startup_log EXIT
xattr -cr "$APP" || true
open "$APP"
if [[ "$MODE" == "desk" ]]; then
  alive=1
else
alive=0
for _ in $(seq 1 40); do
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
  DATA="$HOME/Library/Application Support/SchoolDesk Demo"
  mkdir -p "$DATA"
  capture() {
    local role="$1" page="$2" dest="$3" need="$4" forbid="${5:-}"
    killall schooldesk || true
    sleep 1
    rm -f "$DATA/smoke-role" "$DATA/smoke-page"
    if [[ -n "$role" ]]; then printf '%s' "$role" > "$DATA/smoke-role"; fi
    if [[ -n "$page" ]]; then printf '%s' "$page" > "$DATA/smoke-page"; fi
    open "$APP"
    local text="" wid=""
    for _ in $(seq 1 25); do
      sleep 1
      wid="$(swift -e 'import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in info {
  let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
  if owner.lowercased().contains("school") {
    print(w[kCGWindowNumber as String] ?? "")
    break
  }
}')" || true
      wid="$(printf '%s' "$wid" | tr -d '[:space:]')"
      if [[ -z "$wid" ]]; then
        continue
      fi
      screencapture -x -l "$wid" "$dest" || true
      if [[ ! -f "$dest" ]]; then
        continue
      fi
      text="$(swift "$ROOT/scripts/mac_ui.swift" ocr "$dest" || true)"
      if printf '%s\n' "$text" | grep -q "Unlock"; then
        echo "unlock screen on $dest"
        printf '%s\n' "$text"
        exit 1
      fi
      local ready=1
      local part
      IFS='|' read -ra parts <<< "$need"
      for part in "${parts[@]}"; do
        if ! printf '%s\n' "$text" | grep -q "$part"; then
          ready=0
        fi
      done
      if [[ "$ready" == 1 ]]; then
        break
      fi
    done
    printf '%s\n' "$text"
    local bmp="${dest%.png}.bmp"
    sips -s format bmp "$dest" --out "$bmp" >/dev/null
    python3 "$ROOT/scripts/not_blank.py" "$bmp"
    local part
    IFS='|' read -ra parts <<< "$need"
    for part in "${parts[@]}"; do
      if ! printf '%s\n' "$text" | grep -q "$part"; then
        echo "missing '$part' on $dest"
        exit 1
      fi
    done
    if [[ -n "$forbid" ]] && printf '%s\n' "$text" | grep -q "$forbid"; then
      echo "found '$forbid' on $dest"
      exit 1
    fi
    if [[ -z "$page" && -n "$role" ]] && ! printf '%s\n' "$text" | grep -q "Dashboard"; then
      echo "home page was blank on $dest"
      exit 1
    fi
  }
  OUT="$(dirname "$SHOT")"
  capture admin "" "$OUT/admin-home.png" "Classes" "My class"
  capture director "" "$OUT/director-home.png" "Classes" "My class"
  capture homeroom "" "$OUT/homeroom-home.png" "Dashboard"
  capture subject "" "$OUT/subject-home.png" "Dashboard"
  capture admin classes "$OUT/classes.png" "1-1" "My class"
  capture admin class "$OUT/class-detail.png" "Tesfay Gebreyesus|boys"
  capture admin class-marks "$OUT/class-marks.png" "Abel Tesfamariam|Selam Ghebremedhin|Yonas Habte|Rank|Pass" "Ranks 1, 2, 2, 4"
  capture admin class-marks-sorted "$OUT/class-marks-sorted.png" "Descending|Abel Tesfamariam|Rank" "Rank 1 is at the top"
  capture admin class-fees "$OUT/class-fees.png" "Yearly|Left"
  capture admin find "$OUT/student-search.png" "Abel Tesfamariam"
  capture admin profile "$OUT/student-profile.png" "Abel Tesfamariam|Roll no.|Class 8-1| / 100|CA " "0.0/0.0"
  capture subject marks "$OUT/marks.png" "English"
  capture admin results "$OUT/results.png" "Make statistics"
  capture admin fees "$OUT/fees.png" "Whole school"
  capture admin attendance "$OUT/attendance.png" "Tesfay"
  capture admin attendance-by-number "$OUT/attendance-by-number.png" "Biniam Haile|Genet Weldemichael|Absent|Present today" "No student with number"
  capture admin marks-entry-by-number "$OUT/marks-entry-by-number.png" "Amanuel Araya|Score"
  capture admin timetable "$OUT/timetable.png" "Make the week"
  capture director reports "$OUT/reports.png" "Save PDF"
  capture admin staff "$OUT/staff.png" "Add a person"
  cp "$OUT/admin-home.png" "${SHOT%.png}-home.png"
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
