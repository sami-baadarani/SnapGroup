# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Open `SnapGroup.xcodeproj` in Xcode and build with Cmd+B or run with Cmd+R.

**Dependencies:** The project uses the HotKey Swift Package (https://github.com/soffes/HotKey) for global hotkey handling. It's already configured in the project.

## Project Configuration

- **macOS Deployment Target:** 26.1
- **App Sandbox:** Disabled (required for Accessibility API)
- **LSUIElement:** YES (hides app from Dock and Cmd+Tab)
- **Bundle ID:** dev.samib.SnapGroup

## Architecture

SnapGroup is a macOS menu bar app for window grouping. Users tag windows to groups (1-5) and recall them instantly via hotkeys using Z-order manipulation (no desktop switching animations).

### Core Components

**AppDelegate.swift** - Entry point. Initializes components, subscribes to settings changes, and manages HotKey instances via `rebindHotkeys()`.

**GroupManager.swift** - Window management engine using macOS Accessibility API (AXUIElement). Key operations:
- `TrackedWindow` struct caches `element`, `title`, and `pid` at tag time — menu bar and `getWindowTitles()` never make live AX queries
- `tagWindow(toGroup:)` - Adds focused window to a group
- `untagWindow(fromGroup:)` - Removes the focused window from a group
- `recallGroup(_)` - Brings all windows in a group to front via `bringWindowToFront()`
- Auto-cleanup of closed windows via `isWindowValid()` checks
- `getFocusedWindow()` retries up to 3 times with short delays to handle transient AX errors and focus transitions
- Self-focus skip: ignores SnapGroup's own PID during focused-window lookup so hotkeys work reliably
- `onUserMessage` callback for user-facing notifications (paired with `NSSound.beep()`)

**HotkeySettings.swift** - Singleton storing hotkey bindings in UserDefaults. Default hotkeys: Ctrl+[1-5] for recall, Ctrl+Shift+[1-5] for tag. Notifies subscribers via `onSettingsChanged` callback.

**MenuBarController.swift** - NSStatusItem menu showing group status, window counts, and Preferences access.

**PreferencesWindowController.swift** + **HotkeyRecorderView.swift** - Preferences window with click-to-record hotkey fields.

### Data Flow

1. User presses hotkey → HotKey library triggers handler
2. Handler calls GroupManager method (tag/recall)
3. GroupManager uses AXUIElement API to manipulate windows
4. GroupManager notifies via `onGroupsChanged` callback
5. MenuBarController updates menu to reflect new state

### Key Technical Details

**Carbon Key Codes** (for HotkeySettings defaults):
- Keys 1-4: 18, 19, 20, 21
- Key 5: **23** (not 22)
- Key 6: 22

**Window Activation:** Uses `NSRunningApplication.activate()` + `AXUIElementPerformAction(kAXRaiseAction)` to bring specific windows forward without affecting other windows of the same app.

**Accessibility Permission:** Required for all window operations.
- On launch, checks with `prompt: false` (no dialog on every rebuild)
- Only prompts the system dialog once per session, triggered when an actual AX error occurs during use
- 5-second permission cache (`isPermissionGranted()`) reduces repeated `AXIsProcessTrustedWithOptions` system calls
- `isAccessibilityError()` distinguishes transient AX errors (`.cannotComplete`, `.apiDisabled` while permission is granted) from real permission denials

**Window Validation:** `isWindowValid()` checks process alive → AX role check → keeps window if process is alive but AX is transiently unavailable (`.cannotComplete`, `.apiDisabled`).
