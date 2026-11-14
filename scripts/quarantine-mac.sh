#!/bin/bash
set -euo pipefail
APP="$1"
REPORT="$2"
mkdir -p "$(dirname "$REPORT")"
{
  echo "codesign verify:"
  codesign --verify --deep --strict --verbose=2 "$APP"
  echo
  echo "spctl before quarantine is removed:"
  spctl -a -vv "$APP" || true
  echo
  echo "The ad-hoc signature is expected to be rejected by spctl."
} | tee "$REPORT"

DEST="${HOME}/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/SchoolDesk Demo.app"
cp -R "$APP" "$DEST/SchoolDesk Demo.app"
xattr -w com.apple.quarantine "0083;$(date +%s);Google Drive;00000000-0000-0000-0000-000000000000" "$DEST/SchoolDesk Demo.app" || true
echo "Open while quarantine is still set:" | tee -a "$REPORT"
if open "$DEST/SchoolDesk Demo.app"; then
  sleep 3
  if pgrep -x schooldesk >/dev/null; then
    echo "The app process started even with quarantine. Gatekeeper may be off on this machine." | tee -a "$REPORT"
    killall schooldesk || true
  else
    echo "open returned, but the app did not stay open. macOS is holding it for Privacy and Security." | tee -a "$REPORT"
  fi
else
  echo "open failed while the quarantine attribute was set." | tee -a "$REPORT"
fi
killall schooldesk || true
echo "Removing quarantine and opening again." | tee -a "$REPORT"
xattr -dr com.apple.quarantine "$DEST/SchoolDesk Demo.app"
xattr -l "$DEST/SchoolDesk Demo.app" | tee -a "$REPORT" || true
