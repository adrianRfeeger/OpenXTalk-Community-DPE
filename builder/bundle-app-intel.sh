#!/bin/bash
#
# bundle-app-intel.sh - Build Intel-only (x86_64) app bundle
#
# This is a convenience wrapper for bundle-app.sh that builds an Intel-only
# app for older Macs. The resulting app is smaller than Universal but only
# runs on Intel Macs (or Apple Silicon Macs via Rosetta 2).
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/bundle-app.sh" --arch intel "$@"
