#!/bin/bash
#
# bundle-app-universal.sh - Build Universal (arm64 + x86_64) app bundle
#
# This is a convenience wrapper for bundle-app.sh that builds a Universal binary
# app that runs natively on both Intel and Apple Silicon Macs.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/bundle-app.sh" --arch universal "$@"
