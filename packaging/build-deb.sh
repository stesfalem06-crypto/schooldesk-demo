#!/bin/sh
# Builds an arm64 package. The program file is already compiled.
# Usage: sh packaging/build-deb.sh dist/schooldesk-server-linux-arm64
set -eu
BIN="${1:-}"
VERSION="${2:-1.0.0}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
if [ -z "$BIN" ] || [ ! -f "$BIN" ]; then
  echo "Pass the arm64 server program."
  exit 2
fi
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/opt/schooldesk" "$STAGE/etc/systemd/system" "$STAGE/DEBIAN" "$ROOT/dist"
install -m 0755 "$BIN" "$STAGE/opt/schooldesk/schooldesk-server"
install -m 0644 "$ROOT/packaging/schooldesk.service" "$STAGE/etc/systemd/system/schooldesk.service"
cat > "$STAGE/DEBIAN/control" << EOF
Package: shamm-school-server
Version: $VERSION
Section: misc
Priority: optional
Architecture: arm64
Maintainer: 9 Multimedia and IT solutions <shamm@localhost>
Description: Shamm School Management Systems server
 The school server. It starts on its own and does not use the internet.
EOF
cat > "$STAGE/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -eu
id schooldesk >/dev/null 2>&1 || useradd --system --home /var/lib/schooldesk --shell /usr/sbin/nologin schooldesk || true
install -d -o schooldesk -g schooldesk -m 0750 /var/lib/schooldesk
if command -v ufw >/dev/null 2>&1; then
  ufw allow 8741/tcp >/dev/null 2>&1 || true
  ufw allow 8742/udp >/dev/null 2>&1 || true
fi
systemctl daemon-reload || true
systemctl enable --now schooldesk.service || true
EOF
chmod 0755 "$STAGE/DEBIAN/postinst"
cat > "$STAGE/DEBIAN/prerm" << 'EOF'
#!/bin/sh
systemctl disable --now schooldesk.service >/dev/null 2>&1 || true
EOF
chmod 0755 "$STAGE/DEBIAN/prerm"
OUT="$ROOT/dist/shamm-school-server_${VERSION}_arm64.deb"
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$OUT"
rm -rf "$STAGE"
echo "Wrote $OUT"
