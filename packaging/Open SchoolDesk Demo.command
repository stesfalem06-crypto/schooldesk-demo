#!/bin/bash
cd "$(dirname "$0")"
xattr -dr com.apple.quarantine "SchoolDesk Demo.app" 2>/dev/null || true
open "SchoolDesk Demo.app"
