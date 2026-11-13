#!/bin/sh
set -eu
cd "$(dirname "$0")/../server"
out="$(pwd)/../dist"
mkdir -p "$out"
echo "Running tests"
go test ./...
echo "Building server programs"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "$out/schooldesk-server-linux-amd64" ./cmd/schooldesk-server
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o "$out/schooldesk-server-linux-arm64" ./cmd/schooldesk-server
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "$out/schooldesk-server-windows-amd64.exe" ./cmd/schooldesk-server
echo "Wrote:"
ls -lh "$out"
