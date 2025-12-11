# OpenXTalk Community Edition 

> ⚠️ **Work in Progress** — This fork is under active development with ARM64/Apple Silicon support. More updates coming soon!

OpenXTalk is derived from legacy LiveCode Community Edition code base that is Copyright © 2003-2019 LiveCode Ltd., Edinburgh, UK

## What's New in This Fork

This fork adds **ARM64/Apple Silicon support** for macOS, enabling OpenXTalk to run natively on M1/M2/M3/M4 Macs.

### ✅ Completed Features

- **Universal Binary Support** — Builds for both `arm64` and `x86_64` architectures
- **Apple Silicon Native** — Runs natively on M-series Macs without Rosetta 2
- **Updated Build System** — gyp/Xcode project generation updated for modern macOS SDKs
- **Python 3 Compatibility** — Build scripts updated from Python 2 to Python 3
- **libffi ARM64 Fix** — FFI trampoline system updated for ARM64 compatibility
- **Modern macOS Bundling** — New `bundle-app.sh` script creates distributable app bundles and DMGs
- **Code Signing Ready** — Supports ad-hoc and Developer ID signing with hardened runtime
- **Multi-Architecture Standalone Building** — Build standalone applications for Universal, ARM64-only, or Intel-only targets

### 🆕 Standalone Architecture Options

The Standalone Application Settings now include three macOS architecture options:

| Option | Description | Output Folder |
|--------|-------------|---------------|
| **Universal (arm64 & x86-64)** | Runs on both Apple Silicon and Intel Macs | `/universal/` |
| **Apple Silicon (arm64)** | ARM64-only, smaller size, Apple Silicon Macs only | `/arm64/` |
| **Intel (x86-64)** | Intel-only, for older Macs or compatibility testing | `/x86-64/` |

When multiple architecture options are selected, each is built to its own subfolder within the output directory.

### 🚧 Known Issues (Work in Progress)

- **Window Ordering** — Some window ordering issues when interacting with palettes and dialogs
- **Testing** — Comprehensive testing on various macOS versions still in progress

### 📋 Coming Soon

- Further window management fixes for modern macOS
- Additional testing and bug fixes
- Documentation updates

## Introduction

The OpenXTalk Community open source platform provides a way to build applications for mobile, desktop and server platforms.

## Quick Start (macOS ARM64/Intel)

### Building from Source

```bash
# Clone the repository with submodules
git clone --recursive https://github.com/adrianRfeeger/OpenXTalk-Community-DPE.git
cd OpenXTalk-Community-DPE

# Generate Xcode project
make config-mac

# Build (Universal Binary: arm64 + x86_64)
make compile-mac

# Or build directly with Xcode
xcodebuild -project build-mac/livecode/engine/engine.xcodeproj \
    -target development -configuration Release \
    -arch arm64 -arch x86_64
```

### Creating a Distributable App

```bash
# Create bundled app with DMG
./builder/bundle-app.sh -d

# Output: dist/OpenXTalk-Community.app and dist/OpenXTalk-Community.dmg
```

### Bundle Script Options

```bash
./builder/bundle-app.sh [options]
  -a, --arch ARCH           Architecture: universal, arm64, or x86-64 (default: universal)
  -d, --dmg                 Create a DMG file
  -c, --codesign IDENTITY   Code signing identity (default: ad-hoc)
  -n, --notarize            Prepare for notarisation
  -o, --output DIR          Output directory (default: ./dist)
  -h, --help                Show help
```

The bundle script creates three runtime engine folders for standalone building:
- `/universal/` — Universal binary runtime (arm64 + x86-64)
- `/arm64/` — ARM64-only runtime for Apple Silicon
- `/x86-64/` — Intel-only runtime for x86-64

## Overview

### Subproject directories

This repository contains a number of subprojects, each of which has its own subdirectory.  They can be divided into three main categories.

1. Main system:

  * `engine/` — The main OpenXTalk engine.  This directory produces the IDE, "standalone", "installer" and "server" engines

2. Non-third-party libraries:

  * `libcore/` — A static library that provides various basic functions and types, and is used by many of the other subprojects

  * `libexternal/` and `libexternalv1` — Static libraries that support the OpenXTalk "external" interface, which allows the engine to load plugins

3. Externals (libraries that can be dynamically loaded into the engine at runtime):

  * `revdb/` — Database access external, and drivers for various backend database systems

  * `revmobile/` — The iOS support external (which can only be built on Mac) and the Android support external (available on all desktop platforms)

  * `revpdfprinter/` — Print-to-PDF functionality

  * `revspeech/` — Text-to-speech support

  * `revvideograbber/` — Video capture (Windows only)

  * `revxml/` — XML parsing and generation

  * `revzip/` - Zip archive management

### Engine flavours

The engine — which loads, saves, manages and runs OpenXTalk stack files — can be built in several different specialized modes, which are adapted for various specific purposes.  They are exposed as separate targets in the build system.

1. **IDE engine** (`development` target)— Used to run the IDE.  It contains extra support for things like syntax handling and building OpenXTalk "standalone" programs.

2. **Installer engine** (`installer` target) — Used to create the OpenXTalk installer.  It contains extra support for things like handling zip archives and comparing binary files.

3. **Server engine** (`server` target) — This is the engine used in a server context, when no graphical user interface is needed.  It contains server-specific functions such as CGI support.  It also has a much fewer system library dependencies (and requires only non-desktop APIs where possible).

4. **Standalone engine** (`standalone` target) — The engine that is embedded in "standalone apps" created with OpenXTalk.

## Compiling OpenXTalk

OpenXTalk uses the [gyp (Generate Your Projects)](https://chromium.googlesource.com/external/gyp.git) tool to generate platform-specific project files.  It can generate `xcodeproj` files for Xcode on Mac, `vcproj` files for Microsoft Visual Studio, and makefiles for compiling on Linux.

### Quick start

**Note**: You can only compile OpenXTalk from a clone of the
[OpenXTalk-DPE git repository](https://github.com/PaulMcClernan/OpenXTalkComunity-DPE/) on
GitHub.  See also the GitHub documentation on
[cloning a repository](https://help.github.com/articles/cloning-a-repository/).

On Linux or Mac, you can quickly build OpenXTalk by installing basic development tools, and then running `make all`.

### Detailed instructions

Please see the following table, which shows which target platforms are supported by which host platforms.  The documentation for compiling for each target platform is linked.

| Target platform                                            | Host platforms    |
| ---------------------------------------------------------- | ----------------- |
| [mac, ios](docs/development/build-mac.md)                  | mac               |
| [win](docs/development/build-win.md)                       | win, linux (Wine) |
| [linux](docs/development/build-linux.md)                   | linux             |
| [android](docs/development/build-android.md)               | mac, linux        |
| [emscripten (html5)](docs/development/build-emscripten.md) | linux             |

## Getting help and Gifting Help

For help with installing and using OpenXTalk or if you have discovered a bug, have a feature request, or have written a patch to improve OpenXTalk, drop by in and join the fun https://forums.openxtalk.org/:

* Visit the [OpenXTalk open source forums](https://forums.openxtalk.org/).

## Contributing to OpenXTalk

For information on modifying OpenXTalk and submitting contributions to the OpenXTalk Community project, please see the [CONTRIBUTING](CONTRIBUTING.md) file.

## License

OpenXTalk Community is freely distributable under the GNU Public License (GPL3), with some special exceptions.

For more information, please see the [LICENSE](LICENSE) file in this repository.

The OpenXTalk Community engine, libraries, and associated files are, unless otherwise noted:
Copyright © 2003-2019 LiveCode Ltd.
