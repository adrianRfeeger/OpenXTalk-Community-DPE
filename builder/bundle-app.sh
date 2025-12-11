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
#   -a, --arch ARCH           Architecture: universal, intel, arm64 (default: universal)
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
ARCH="universal"

# App name configuration
APP_NAME="OpenXTalk-Community"
DMG_NAME="OpenXTalk-Community"
VOLUME_NAME="OpenXTalk Community"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
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
            echo "  -a, --arch ARCH           Architecture: universal, intel, arm64 (default: universal)"
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

# Validate architecture option
case "${ARCH}" in
    universal|intel|arm64)
        ;;
    *)
        echo "ERROR: Invalid architecture '${ARCH}'. Must be: universal, intel, or arm64"
        exit 1
        ;;
esac

echo "=== OpenXTalk App Bundler for macOS ==="
echo "Architecture: ${ARCH}"
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

# Function to thin a binary to a specific architecture
thin_binary() {
    local file="$1"
    local arch="$2"
    
    if [ -f "$file" ] && file "$file" | grep -q "universal binary"; then
        local lipo_arch
        case "$arch" in
            intel) lipo_arch="x86_64" ;;
            arm64) lipo_arch="arm64" ;;
        esac
        
        if lipo "$file" -verify_arch "$lipo_arch" 2>/dev/null; then
            lipo "$file" -thin "$lipo_arch" -output "${file}.thin"
            mv "${file}.thin" "$file"
        fi
    fi
}

# Function to thin all binaries in a directory
thin_directory() {
    local dir="$1"
    local arch="$2"
    
    # Thin Mach-O executables and libraries
    find "$dir" -type f \( -perm +111 -o -name "*.dylib" -o -name "*.so" \) 2>/dev/null | while read -r file; do
        thin_binary "$file" "$arch"
    done
    
    # Thin binaries inside .bundle and .app directories
    find "$dir" -type d \( -name "*.bundle" -o -name "*.app" \) 2>/dev/null | while read -r bundle; do
        find "$bundle" -type f \( -perm +111 -o -name "*.dylib" \) 2>/dev/null | while read -r file; do
            thin_binary "$file" "$arch"
        done
    done
}
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

# Copy IDE Toolset (required for the app to start)
IDE_DIR="${PROJECT_ROOT}/ide"
if [ -d "${IDE_DIR}" ]; then
    echo "Bundling IDE..."
    mkdir -p "${RESOURCES}/ide"
    
    # Copy Toolset (required)
    if [ -d "${IDE_DIR}/Toolset" ]; then
        echo "  Copying Toolset..."
        cp -R "${IDE_DIR}/Toolset" "${RESOURCES}/ide/"
    fi
    
    # Copy Plugins
    if [ -d "${IDE_DIR}/Plugins" ]; then
        echo "  Copying Plugins..."
        cp -R "${IDE_DIR}/Plugins" "${RESOURCES}/ide/"
    fi
    
    # Copy Resources
    if [ -d "${IDE_DIR}/Resources" ]; then
        echo "  Copying IDE Resources..."
        cp -R "${IDE_DIR}/Resources" "${RESOURCES}/ide/"
    fi
    
    # Copy Documentation
    if [ -d "${IDE_DIR}/Documentation" ]; then
        echo "  Copying Documentation..."
        cp -R "${IDE_DIR}/Documentation" "${RESOURCES}/ide/"
    fi
    
    # Copy license files
    for file in "${IDE_DIR}"/*.txt "${IDE_DIR}"/*.pdf; do
        if [ -f "$file" ]; then
            cp "$file" "${RESOURCES}/ide/" 2>/dev/null || true
        fi
    done
    
    # Create Externals folder with bundles (for installed app path lookup)
    echo "  Setting up Externals folder..."
    mkdir -p "${RESOURCES}/ide/Externals"
    for bundle in "${BUILD_DIR}"/*.bundle; do
        if [ -d "$bundle" ]; then
            cp -R "$bundle" "${RESOURCES}/ide/Externals/"
        fi
    done
    # Also copy dylibs that might be needed
    for dylib in "${BUILD_DIR}"/*.dylib; do
        if [ -f "$dylib" ]; then
            cp "$dylib" "${RESOURCES}/ide/Externals/"
        fi
    done
    
    # Create Extensions folder from packaged_extensions
    if [ -d "${BUILD_DIR}/packaged_extensions" ]; then
        echo "  Setting up Extensions folder..."
        mkdir -p "${RESOURCES}/ide/Extensions"
        cp -R "${BUILD_DIR}/packaged_extensions"/* "${RESOURCES}/ide/Extensions/" 2>/dev/null || true
    fi
fi

# Copy ide-support folder (contains essential libraries like revSaveAsStandalone)
# Place inside ide/ folder so it's in sToolsPath and can be found by revInternal__StackFiles
IDE_SUPPORT_DIR="${PROJECT_ROOT}/ide-support"
if [ -d "${IDE_SUPPORT_DIR}" ]; then
    echo "Bundling ide-support libraries..."
    cp -R "${IDE_SUPPORT_DIR}" "${RESOURCES}/ide/"
fi

# Create Runtime folder with standalone engines for building standalones
echo "Setting up Runtime folder for standalone building..."
RUNTIME_DIR="${RESOURCES}/ide/Runtime"
mkdir -p "${RUNTIME_DIR}"

# Mac OS X runtime (Universal binary - arm64 + x86_64)
# Copy to 'universal', 'arm64', and 'x86-64' folders for all three Mac targets
if [ -d "${BUILD_DIR}/Standalone-Community.app" ]; then
    echo "  Copying Mac OS X runtime (Universal binary)..."
    
    # Universal folder for MacOSX Universal target
    mkdir -p "${RUNTIME_DIR}/Mac OS X/universal"
    cp -R "${BUILD_DIR}/Standalone-Community.app" "${RUNTIME_DIR}/Mac OS X/universal/Standalone.app"
    
    # ARM64 folder for MacOSX ARM64 target (thin to arm64 only)
    mkdir -p "${RUNTIME_DIR}/Mac OS X/arm64"
    cp -R "${BUILD_DIR}/Standalone-Community.app" "${RUNTIME_DIR}/Mac OS X/arm64/Standalone.app"
    if [ "${ARCH}" = "universal" ]; then
        echo "    Thinning ARM64 runtime to arm64 only..."
        thin_directory "${RUNTIME_DIR}/Mac OS X/arm64" "arm64"
    fi
    
    # x86-64 folder for MacOSX Intel target (thin to x86_64 only)
    mkdir -p "${RUNTIME_DIR}/Mac OS X/x86-64"
    cp -R "${BUILD_DIR}/Standalone-Community.app" "${RUNTIME_DIR}/Mac OS X/x86-64/Standalone.app"
    if [ "${ARCH}" = "universal" ]; then
        echo "    Thinning Intel runtime to x86_64 only..."
        thin_directory "${RUNTIME_DIR}/Mac OS X/x86-64" "intel"
    fi
fi

# Rename the rsrc file to match executable
if [ -f "${RESOURCES}/LiveCode-Community.rsrc" ]; then
    mv "${RESOURCES}/LiveCode-Community.rsrc" "${RESOURCES}/${APP_NAME}.rsrc"
fi

# Create a launcher script that sets REV_TOOLS_PATH
echo "Creating launcher script..."
REAL_EXECUTABLE="${APP_NAME}-bin"
mv "${MACOS}/${APP_NAME}" "${MACOS}/${REAL_EXECUTABLE}"

cat > "${MACOS}/${APP_NAME}" << 'LAUNCHER'
#!/bin/bash
# Launcher script for OpenXTalk
# Sets up environment and launches the real executable

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Set REV_TOOLS_PATH to the bundled IDE
export REV_TOOLS_PATH="${RESOURCES_DIR}/ide"

# Launch the real executable
exec "${SCRIPT_DIR}/OpenXTalk-Community-bin" "$@"
LAUNCHER

chmod +x "${MACOS}/${APP_NAME}"

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
if [ -f "${MACOS}/${REAL_EXECUTABLE}" ]; then
    for dylib in "${FRAMEWORKS}"/*.dylib; do
        if [ -f "$dylib" ]; then
            dylib_name=$(basename "$dylib")
            # Try to update the path in the executable
            install_name_tool -change "@rpath/${dylib_name}" "@executable_path/../Frameworks/${dylib_name}" "${MACOS}/${REAL_EXECUTABLE}" 2>/dev/null || true
            install_name_tool -change "${BUILD_DIR}/${dylib_name}" "@executable_path/../Frameworks/${dylib_name}" "${MACOS}/${REAL_EXECUTABLE}" 2>/dev/null || true
        fi
    done
fi

# Thin binaries if not building universal
if [ "$ARCH" != "universal" ]; then
    echo "Thinning binaries to ${ARCH} architecture..."
    thin_directory "${APP_BUNDLE}" "${ARCH}"
    echo "  Done thinning binaries"
fi

# Strip extended attributes and resource forks (required for code signing)
echo "Stripping extended attributes..."
xattr -cr "${APP_BUNDLE}"

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
