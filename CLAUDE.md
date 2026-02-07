# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Open `SnapGroup.xcodeproj` in Xcode and build with Cmd+B or run with Cmd+R.

**Dependencies:** The project uses the HotKey Swift Package (https://github.com/soffes/HotKey) for global hotkey handling. It's already configured in the project.

## Project Configuration

- **App Sandbox:** Disabled (required for Accessibility API)
- **LSUIElement:** YES (hides app from Dock and Cmd+Tab)
- **Bundle ID:** dev.samib.SnapGroup

## Architecture

SnapGroup is a macOS menu bar app for window grouping. Users tag windows to groups (1-5) and recall them instantly via hotkeys using Z-order manipulation (no desktop switching animations).

### Core Components

**AppDelegate.swift** - Entry point. Initializes components, subscribes to settings changes, and manages HotKey instances via `rebindHotkeys()`.

**GroupManager.swift** - Window management engine using macOS Accessibility API (AXUIElement). Key operations:
- `tagWindow(toGroup:)` - Adds focused window to a group
- `recallGroup(_)` - Brings all windows in a group to front via `bringWindowToFront()`
- Auto-cleanup of closed windows via `isWindowValid()` checks

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

**Accessibility Permission:** Required on first launch. App prompts via `AXIsProcessTrustedWithOptions`.
