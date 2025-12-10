#!/bin/bash
#
# generate-dmg.sh - Generate a DMG installer for OpenXTalk/LiveCode
#
# This script creates a compressed DMG with the app and an Applications symlink.
# For modern macOS (10.13+), we use ULFO format for better compatibility.
#
# Usage: ./generate-dmg.sh volname srcfolder output
#

set -e

# Arguments are the name of the volume to create, the input folder and the output filename
if [ $# -ne 3 ] ; then
	echo >&2 "ERROR: usage: ./generate-dmg.sh volname srcfolder output"
	exit 2
fi

volname="$1"
srcfolder="$2"
output="$3"

# Remove any existing output file
rm -f "${output}"

# Create a temporary directory for DMG contents
tmpdir=$(mktemp -d)
trap "rm -rf ${tmpdir}" EXIT

# Copy the source folder contents
cp -R "${srcfolder}"/* "${tmpdir}/" 2>/dev/null || cp -R "${srcfolder}" "${tmpdir}/"

# Create Applications symlink if it doesn't exist
if [ ! -e "${tmpdir}/Applications" ]; then
    ln -s /Applications "${tmpdir}/Applications"
fi

# Determine the best format based on macOS version
# ULFO (lzfse) is best for macOS 10.11+, UDBZ (bzip2) for older
macos_version=$(sw_vers -productVersion | cut -d. -f1,2)
if [[ "${macos_version}" > "10.10" ]] || [[ "${macos_version}" == "10.10" ]]; then
    format="ULFO"
else
    format="UDBZ"
fi

echo "Creating DMG with format ${format}..."

# Create the DMG
# Note: We don't need root permissions for modern DMG creation
hdiutil create \
    -volname "${volname}" \
    -srcfolder "${tmpdir}" \
    -ov \
    -format "${format}" \
    "${output}"

# Set permissions
chmod 644 "${output}"

echo "DMG created: ${output}"
echo "Volume name: ${volname}"
echo "Format: ${format}"
