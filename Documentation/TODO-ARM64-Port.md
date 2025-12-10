# OpenXTalk ARM64 Port - TODO Items

## Completed ✅

### Build System
- [x] Configure gyp build system for ARM64 architecture
- [x] Create Universal Binary build (x86_64 + arm64)
- [x] Fix Python 3 compatibility issues in build scripts
- [x] Update SDK paths for modern Xcode

### Runtime Fixes
- [x] Fix libffi ARM64 support (FFI_EXEC_TRAMPOLINE_TABLE)
- [x] Fix version check in home.livecodescript to allow version 8 stacks
- [x] Fix null pointer crashes in mac-menu.mm (MCPlatformReleaseMenu, MCPlatformDestroyMenuItem)
- [x] Add re-entrancy guard for focus handling in card.cpp (kfocusnext)
- [x] Add focus event guard in mac-window.mm (makeFirstResponder)

---

## Known Issues / Future Work 🔧

### Window Ordering During Drag-Drop (Low Priority)
**Status:** Shelved - minor cosmetic issue

**Description:**  
When dragging from the toolbar palette, the stack window and backdrop briefly go behind other applications on the first drag attempt. After clicking on the app to bring it back to front, subsequent drags work correctly.

**Observed Behaviour:**
- First drag from toolbar causes windows to go to back
- Clicking on app brings windows back to front
- Subsequent drags work normally

**Technical Notes:**
- Issue occurs during NSDraggingSource operations
- macOS automatically changes window ordering when initiating drags from NSPanel/floating windows
- Attempted fixes with `orderFrontRegardless`, `activateIgnoringOtherApps`, `preventWindowOrdering` were too aggressive and broke other functionality
- The `dispatch_after` approach to restore ordering also caused issues

**Potential Solutions to Investigate:**
1. Override `acceptsFirstMouse:` to return YES for drag sources
2. Use `NSWindow.orderingMode` property
3. Investigate `NSPanel.becomesKeyOnlyIfNeeded`
4. Look at Apple's drag-and-drop sample code for proper window level handling
5. Consider using `NSFloatingWindowLevel` vs `kCGFloatingWindowLevel` differences

**Files Involved:**
- `engine/src/mac-window.mm` - MCWindowView drag methods
- Methods: `dragImage:offset:allowing:pasteboard:`, `draggedImage:beganAt:`, `draggingEntered:`

---

## Testing Notes

### Build Command
```bash
cd /Users/adrianfeeger/Development/Python/OpenXTalk-Community-DPE
xcodebuild -project build-mac/livecode/engine/engine.xcodeproj \
  -target development \
  -configuration Release \
  -arch arm64 -arch x86_64 \
  MACOSX_DEPLOYMENT_TARGET=10.9 \
  GCC_WARN_64_TO_32_BIT_CONVERSION=NO
```

### Launch Command
```bash
export REV_TOOLS_PATH="/path/to/OpenXTalk-Community-DPE/ide"
/path/to/OpenXTalk-Community-DPE/_build/mac/Release/LiveCode-Community.app/Contents/MacOS/LiveCode-Community
```

### Verify Universal Binary
```bash
lipo -info _build/mac/Release/LiveCode-Community.app/Contents/MacOS/LiveCode-Community
# Should output: Architectures in the fat file: ... are: x86_64 arm64
```

---

## Date
Last Updated: 10 December 2025
