//
//  GroupManager.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import ApplicationServices

class GroupManager {
    // A dictionary to store groups: [GroupNumber : [WindowElements]]
    private var groups: [Int: [AXUIElement]] = [:]

    // Callback for when groups change (for menu bar updates)
    var onGroupsChanged: (() -> Void)?

    // Check if we have Accessibility Permissions
    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // Check if a window reference is still valid
    private func isWindowValid(_ window: AXUIElement) -> Bool {
        var title: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        return result == .success
    }

    // Clean up invalid windows from a group
    private func cleanupInvalidWindows(in group: Int) {
        guard var windows = groups[group] else { return }
        let originalCount = windows.count
        windows = windows.filter { isWindowValid($0) }
        if windows.count != originalCount {
            groups[group] = windows
            print("Cleaned up \(originalCount - windows.count) invalid window(s) from Group \(group)")
            onGroupsChanged?()
        }
    }

    // Get the focused window's parent window (handles cases where a UI element inside a window is focused)
    private func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp as! AXUIElement? else {
            return nil
        }

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow as! AXUIElement? else {
            return nil
        }

        return window
    }

    // Tag the Currently Focused Window
    func tagWindow(toGroup group: Int) {
        guard let window = getFocusedWindow() else {
            print("No window focused")
            return
        }

        // Get window title for logging
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? "Unknown"

        // Initialize array if nil
        if groups[group] == nil { groups[group] = [] }

        // Check for duplicates
        let exists = groups[group]?.contains(where: { CFEqual($0, window) }) ?? false

        if !exists {
            groups[group]?.append(window)
            print("Tagged '\(title)' to Group \(group)")
            onGroupsChanged?()
        } else {
            print("Window '\(title)' already in Group \(group)")
        }
    }

    // Remove the focused window from a group
    func untagWindow(fromGroup group: Int) {
        guard let window = getFocusedWindow() else {
            print("No window focused")
            return
        }

        guard var windows = groups[group] else {
            print("Group \(group) is empty")
            return
        }

        let originalCount = windows.count
        windows = windows.filter { !CFEqual($0, window) }

        if windows.count < originalCount {
            groups[group] = windows
            print("Removed window from Group \(group)")
            onGroupsChanged?()
        } else {
            print("Window not found in Group \(group)")
        }
    }

    // Recall the Group
    func recallGroup(_ group: Int) {
        // Clean up invalid windows first
        cleanupInvalidWindows(in: group)

        guard let windows = groups[group], !windows.isEmpty else {
            print("Group \(group) is empty")
            return
        }

        print("Recalling Group \(group) with \(windows.count) window(s)")

        // Iterate through windows so the first added ends up on top
        for window in windows {
            bringWindowToFront(window)
        }
    }

    // The Magic Z-Order Jump
    private func bringWindowToFront(_ window: AXUIElement) {
        // Get the Process ID (PID) of the app owning the window
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        // Activate that App
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: .activateIgnoringOtherApps)
        }

        // Tell accessibility to "Raise" the specific window
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    // Clear Group
    func clearGroup(_ group: Int) {
        let count = groups[group]?.count ?? 0
        groups[group] = []
        print("Cleared Group \(group) (\(count) window(s))")
        onGroupsChanged?()
    }

    // Clear All Groups
    func clearAllGroups() {
        groups.removeAll()
        print("Cleared all groups")
        onGroupsChanged?()
    }

    // Get group info for menu bar display
    func getGroupInfo() -> [Int: Int] {
        var info: [Int: Int] = [:]
        for i in 1...5 {
            // Clean up invalid windows before reporting
            cleanupInvalidWindows(in: i)
            info[i] = groups[i]?.count ?? 0
        }
        return info
    }

    // Get window titles in a group (for menu display)
    func getWindowTitles(forGroup group: Int) -> [String] {
        guard let windows = groups[group] else { return [] }

        return windows.compactMap { window -> String? in
            var titleValue: AnyObject?
            guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success else {
                return nil
            }
            return titleValue as? String
        }
    }
}
