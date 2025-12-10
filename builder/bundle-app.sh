#!/bin/bash
#
# bundle-app.sh - Bundle OpenXTalk/LiveCode for distribution on modern macOS
#
# This script:
# 1. Creates a distributable app bundle with all dependencies
# 2. Signs the app with ad-hoc signature (or Developer ID if available)
# 3. Optionally creates a DMG for distribution
# 4. Optionally notarises the app for Gatekeeper
#
# Usage: ./bundle-app.sh [options]
#   -c, --codesign IDENTITY   Code signing identity (default: ad-hoc "-")
#   -d, --dmg                 Create a DMG file
#   -n, --notarize            Notarise the app (requires Apple Developer account)
#   -o, --output DIR          Output directory (default: ./dist)
#   -h, --help                Show this help message
#

set -e

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/_build/mac/Release"
OUTPUT_DIR="${PROJECT_ROOT}/dist"
CODESIGN_IDENTITY="-"
CREATE_DMG=false
NOTARIZE=false

# App name configuration
APP_NAME="OpenXTalk-Community"
DMG_NAME="OpenXTalk-Community"
VOLUME_NAME="OpenXTalk Community"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--codesign)
            CODESIGN_IDENTITY="$2"
            shift 2
            ;;
        -d|--dmg)
            CREATE_DMG=true
            shift
            ;;
        -n|--notarize)
            NOTARIZE=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "  -c, --codesign IDENTITY   Code signing identity (default: ad-hoc)"
            echo "  -d, --dmg                 Create a DMG file"
            echo "  -n, --notarize            Notarise the app (requires Apple Developer account)"
            echo "  -o, --output DIR          Output directory (default: ./dist)"
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== OpenXTalk App Bundler for macOS ==="
echo ""

# Check if build exists
if [ ! -d "${BUILD_DIR}/LiveCode-Community.app" ]; then
    echo "ERROR: Build not found at ${BUILD_DIR}/LiveCode-Community.app"
    echo "Please build the project first."
    exit 1
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Copy app to output directory with new name
echo "Copying app bundle..."
rm -rf "${OUTPUT_DIR}/${APP_NAME}.app"
cp -R "${BUILD_DIR}/LiveCode-Community.app" "${OUTPUT_DIR}/${APP_NAME}.app"

APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
FRAMEWORKS="${CONTENTS}/Frameworks"

# Rename the executable
if [ -f "${MACOS}/LiveCode-Community" ]; then
    mv "${MACOS}/LiveCode-Community" "${MACOS}/${APP_NAME}"
fi

# Create Frameworks directory for bundled libraries
mkdir -p "${FRAMEWORKS}"

# Copy required dylibs into Frameworks
echo "Bundling dynamic libraries..."
for dylib in "${BUILD_DIR}"/*.dylib; do
    if [ -f "$dylib" ]; then
        echo "  Copying $(basename "$dylib")..."
        cp "$dylib" "${FRAMEWORKS}/"
    fi
done

# Copy bundles (plugins) into Resources
echo "Bundling plugins..."
for bundle in "${BUILD_DIR}"/*.bundle; do
    if [ -d "$bundle" ]; then
        echo "  Copying $(basename "$bundle")..."
        cp -R "$bundle" "${RESOURCES}/"
    fi
done

# Copy packaged extensions
if [ -d "${BUILD_DIR}/packaged_extensions" ]; then
    echo "Bundling extensions..."
    cp -R "${BUILD_DIR}/packaged_extensions" "${RESOURCES}/"
fi

# Copy modules
if [ -d "${BUILD_DIR}/modules" ]; then
    echo "Bundling modules..."
    cp -R "${BUILD_DIR}/modules" "${RESOURCES}/"
fi

# Update Info.plist with correct executable name and modern settings
echo "Updating Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${CONTENTS}/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName OpenXTalk" "${CONTENTS}/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.openxtalk.community" "${CONTENTS}/Info.plist" 2>/dev/null || true

# Add hardened runtime entitlements for modern macOS
cat > "${OUTPUT_DIR}/entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
</dict>
</plist>
EOF

# Fix library paths for bundled dylibs
echo "Fixing library paths..."
for dylib in "${FRAMEWORKS}"/*.dylib; do
    if [ -f "$dylib" ]; then
        dylib_name=$(basename "$dylib")
        # Update the install name
        install_name_tool -id "@executable_path/../Frameworks/${dylib_name}" "$dylib" 2>/dev/null || true
    fi
done

# Update executable to find bundled libraries
if [ -f "${MACOS}/${APP_NAME}" ]; then
    for dylib in "${FRAMEWORKS}"/*.dylib; do
        if [ -f "$dylib" ]; then
            dylib_name=$(basename "$dylib")
            # Try to update the path in the executable
            install_name_tool -change "@rpath/${dylib_name}" "@executable_path/../Frameworks/${dylib_name}" "${MACOS}/${APP_NAME}" 2>/dev/null || true
            install_name_tool -change "${BUILD_DIR}/${dylib_name}" "@executable_path/../Frameworks/${dylib_name}" "${MACOS}/${APP_NAME}" 2>/dev/null || true
        fi
    done
fi

# Code sign the app
echo "Code signing..."
if [ "$CODESIGN_IDENTITY" = "-" ]; then
    echo "  Using ad-hoc signature (for local testing only)"
    # Sign frameworks first
    find "${FRAMEWORKS}" -name "*.dylib" -exec codesign --force --sign - {} \; 2>/dev/null || true
    # Sign bundles
    find "${RESOURCES}" -name "*.bundle" -exec codesign --force --sign - {} \; 2>/dev/null || true
    # Sign the app
    codesign --force --deep --sign - "${APP_BUNDLE}"
else
    echo "  Using identity: ${CODESIGN_IDENTITY}"
    # Sign with hardened runtime for notarisation
    find "${FRAMEWORKS}" -name "*.dylib" -exec codesign --force --options runtime --sign "${CODESIGN_IDENTITY}" --entitlements "${OUTPUT_DIR}/entitlements.plist" {} \; 2>/dev/null || true
    find "${RESOURCES}" -name "*.bundle" -exec codesign --force --options runtime --sign "${CODESIGN_IDENTITY}" --entitlements "${OUTPUT_DIR}/entitlements.plist" {} \; 2>/dev/null || true
    codesign --force --deep --options runtime --sign "${CODESIGN_IDENTITY}" --entitlements "${OUTPUT_DIR}/entitlements.plist" "${APP_BUNDLE}"
fi

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose=2 "${APP_BUNDLE}" && echo "  Signature valid!" || echo "  WARNING: Signature verification failed"

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    echo ""
    echo "Creating DMG..."
    
    DMG_TEMP="${OUTPUT_DIR}/${DMG_NAME}-temp.dmg"
    DMG_FINAL="${OUTPUT_DIR}/${DMG_NAME}.dmg"
    
    # Remove existing DMG
    rm -f "${DMG_TEMP}" "${DMG_FINAL}"
    
    # Create a temporary folder for DMG contents
    DMG_CONTENTS="${OUTPUT_DIR}/dmg-contents"
    rm -rf "${DMG_CONTENTS}"
    mkdir -p "${DMG_CONTENTS}"
    
    # Copy app
    cp -R "${APP_BUNDLE}" "${DMG_CONTENTS}/"
    
    # Create Applications symlink
    ln -s /Applications "${DMG_CONTENTS}/Applications"
    
    # Create the DMG
    hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${DMG_CONTENTS}" -ov -format UDZO "${DMG_FINAL}"
    
    # Clean up
    rm -rf "${DMG_CONTENTS}"
    
    echo "DMG created: ${DMG_FINAL}"
    
    # Sign DMG if not ad-hoc
    if [ "$CODESIGN_IDENTITY" != "-" ]; then
        echo "Signing DMG..."
        codesign --force --sign "${CODESIGN_IDENTITY}" "${DMG_FINAL}"
    fi
fi

# Notarise if requested
if [ "$NOTARIZE" = true ] && [ "$CODESIGN_IDENTITY" != "-" ]; then
    echo ""
    echo "Notarising app..."
    echo "NOTE: You need to have Apple Developer credentials configured in Keychain"
    
    # Create a zip for notarisation
    NOTARIZE_ZIP="${OUTPUT_DIR}/${APP_NAME}-notarize.zip"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${NOTARIZE_ZIP}"
    
    echo "Please run the following command to submit for notarisation:"
    echo "  xcrun notarytool submit \"${NOTARIZE_ZIP}\" --keychain-profile \"AC_PASSWORD\" --wait"
    echo ""
    echo "After notarisation completes, staple the ticket:"
    echo "  xcrun stapler staple \"${APP_BUNDLE}\""
    if [ "$CREATE_DMG" = true ]; then
        echo "  xcrun stapler staple \"${DMG_FINAL}\""
    fi
fi

echo ""
echo "=== Bundle complete! ==="
echo "App location: ${APP_BUNDLE}"
if [ "$CREATE_DMG" = true ]; then
    echo "DMG location: ${DMG_FINAL}"
fi
echo ""
echo "To test the app, run:"
echo "  open \"${APP_BUNDLE}\""
