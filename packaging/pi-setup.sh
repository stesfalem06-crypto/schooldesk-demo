#!/bin/sh
# Sets up Shamm School Management Systems on a Raspberry Pi (64-bit).
# Copy schooldesk-server-linux-arm64 next to this script, then:
#   sudo sh pi-setup.sh
set -eu
if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo."
  exit 1
fi
SRC="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
BIN="$SRC/schooldesk-server-linux-arm64"
if [ ! -f "$BIN" ]; then
  echo "Put schooldesk-server-linux-arm64 in $SRC first."
  echo "Build it with: cd server && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o ../dist/schooldesk-server-linux-arm64 ./cmd/schooldesk-server"
  exit 1
fi
id schooldesk >/dev/null 2>&1 || useradd --system --home /var/lib/schooldesk --shell /usr/sbin/nologin schooldesk
install -d -o schooldesk -g schooldesk -m 0750 /var/lib/schooldesk /opt/schooldesk
install -o root -g root -m 0755 "$BIN" /opt/schooldesk/schooldesk-server
install -o root -g root -m 0644 "$SRC/schooldesk.service" /etc/systemd/system/schooldesk.service
if command -v ufw >/dev/null 2>&1; then
  ufw allow 8741/tcp >/dev/null 2>&1 || true
  ufw allow 8742/udp >/dev/null 2>&1 || true
fi
systemctl daemon-reload
systemctl enable --now schooldesk.service
echo
echo "Shamm School Management Systems is running on port 8741."
echo "Open http://THIS-PI-ADDRESS:8741 on the school network to see the status page."
echo "Sign-in names for the sample school are in /var/lib/schooldesk/FIRST_LOGIN.txt"
echo
echo "Night backups go to the folder set in Settings."
echo "To use a USB stick:"
echo "  1. Plug it in."
echo "  2. sudo mkdir -p /mnt/schooldesk-backup"
echo "  3. Find it with lsblk, then sudo mount /dev/sdX1 /mnt/schooldesk-backup"
echo "  4. In the admin app, set the backup folder to /mnt/schooldesk-backup"
echo "Add that mount to /etc/fstab if it should come back after a restart."
