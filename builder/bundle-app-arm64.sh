#!/bin/bash
#
# bundle-app-arm64.sh - Build ARM64-only (Apple Silicon) app bundle
#
# This is a convenience wrapper for bundle-app.sh that builds an ARM64-only
# app for Apple Silicon Macs. The resulting app is smaller than Universal but
# only runs on Apple Silicon Macs (M1, M2, M3, etc.).
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/bundle-app.sh" --arch arm64 "$@"
