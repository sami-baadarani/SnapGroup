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
    private var hasPromptedForAccessibilityThisSession = false
    private var cachedPermissionGranted = false
    private var cachedPermissionTimestamp: Date = .distantPast

    // Callback for when groups change (for menu bar updates)
    var onGroupsChanged: (() -> Void)?
    var onUserMessage: ((String) -> Void)?

    private enum FocusedWindowLookupResult {
        case success(AXUIElement)
        case noFocusedWindow
        case accessibilityDenied
        case failure(AXError)
    }

    private enum RaiseWindowResult {
        case success
        case accessibilityDenied
        case failure
    }

    // Check if we have Accessibility Permissions
    func checkPermissions(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func notifyUser(_ message: String) {
        NSSound.beep()
        onUserMessage?(message)
    }

    private func requestAccessibilityPermissionIfNeeded(for action: String) {
        let alreadyGranted = checkPermissions(prompt: false)

        if alreadyGranted {
            print("[SnapGroup] Permission appears granted but AX calls are failing")
            notifyUser("SnapGroup has Accessibility permission but window access is failing. Try removing SnapGroup from Accessibility settings, re-adding it, and restarting the app.")
        } else {
            if !hasPromptedForAccessibilityThisSession {
                _ = checkPermissions(prompt: true)
                hasPromptedForAccessibilityThisSession = true
            }
            notifyUser("SnapGroup needs Accessibility permission to \(action). Please enable it in System Settings > Privacy & Security > Accessibility.")
        }
    }

    // Check if a window reference is still valid
    private func isWindowValid(_ window: AXUIElement) -> Bool {
        var roleValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue)
        guard result == .success, let role = roleValue as? String else {
            return false
        }
        return role == (kAXWindowRole as String)
    }

    // Clean up invalid windows from a group
    private func cleanupInvalidWindows(in group: Int, notifyChange: Bool = true) {
        guard var windows = groups[group] else { return }
        let originalCount = windows.count
        windows = windows.filter { isWindowValid($0) }
        if windows.count != originalCount {
            groups[group] = windows
            print("Cleaned up \(originalCount - windows.count) invalid window(s) from Group \(group)")
            if notifyChange {
                onGroupsChanged?()
            }
        }
    }

    private func isPermissionGranted() -> Bool {
        let now = Date()
        if now.timeIntervalSince(cachedPermissionTimestamp) > 5.0 {
            cachedPermissionGranted = checkPermissions(prompt: false)
            cachedPermissionTimestamp = now
        }
        return cachedPermissionGranted
    }

    private func invalidatePermissionCache() {
        cachedPermissionTimestamp = .distantPast
    }

    // Check if an AX error indicates missing accessibility permission.
    // Both .apiDisabled and .cannotComplete can occur transiently even when
    // permission is granted, so always verify against AXIsProcessTrustedWithOptions.
    private func isAccessibilityError(_ error: AXError) -> Bool {
        guard error == .apiDisabled || error == .cannotComplete else {
            return false
        }
        invalidatePermissionCache()
        let granted = isPermissionGranted()
        print("[SnapGroup] AX error \(error.rawValue) (\(error == .apiDisabled ? "apiDisabled" : "cannotComplete")), permission granted: \(granted)")
        return !granted
    }

    // Get the focused window, retrying once on transient AX errors when permission is granted.
    private func getFocusedWindow() -> FocusedWindowLookupResult {
        let result = getFocusedWindowOnce()
        if case .failure(let error) = result,
           (error == .cannotComplete || error == .apiDisabled),
           isPermissionGranted() {
            print("[SnapGroup] Retrying after transient AX error \(error.rawValue)")
            Thread.sleep(forTimeInterval: 0.1)
            return getFocusedWindowOnce()
        }
        return result
    }

    // Get the focused window's parent window (handles cases where a UI element inside a window is focused)
    private func getFocusedWindowOnce() -> FocusedWindowLookupResult {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success else {
            if isAccessibilityError(appResult) {
                print("[SnapGroup] Focused app lookup denied (AX error: \(appResult.rawValue))")
                return .accessibilityDenied
            }
            if appResult == .noValue {
                return .noFocusedWindow
            }
            print("[SnapGroup] Focused app lookup failed (AX error: \(appResult.rawValue))")
            return .failure(appResult)
        }
        guard let focusedApp else {
            return .noFocusedWindow
        }
        let app = focusedApp as! AXUIElement

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard windowResult == .success else {
            if isAccessibilityError(windowResult) {
                print("[SnapGroup] Focused window lookup denied (AX error: \(windowResult.rawValue))")
                return .accessibilityDenied
            }
            if windowResult == .noValue {
                return .noFocusedWindow
            }
            print("[SnapGroup] Focused window lookup failed (AX error: \(windowResult.rawValue))")
            return .failure(windowResult)
        }
        guard let focusedWindow else {
            return .noFocusedWindow
        }
        let window = focusedWindow as! AXUIElement

        return .success(window)
    }

    // Tag the Currently Focused Window
    func tagWindow(toGroup group: Int) {
        let window: AXUIElement
        switch getFocusedWindow() {
        case .success(let focusedWindow):
            window = focusedWindow
        case .noFocusedWindow:
            print("No window focused")
            NSSound.beep()
            return
        case .accessibilityDenied:
            requestAccessibilityPermissionIfNeeded(for: "tag windows")
            return
        case .failure(let error):
            print("Failed to get focused window (AX error: \(error.rawValue))")
            NSSound.beep()
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
        let window: AXUIElement
        switch getFocusedWindow() {
        case .success(let focusedWindow):
            window = focusedWindow
        case .noFocusedWindow:
            print("No window focused")
            NSSound.beep()
            return
        case .accessibilityDenied:
            requestAccessibilityPermissionIfNeeded(for: "modify groups")
            return
        case .failure(let error):
            print("Failed to get focused window (AX error: \(error.rawValue))")
            NSSound.beep()
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
        var deniedCount = 0
        var failedCount = 0
        for window in windows {
            switch bringWindowToFront(window) {
            case .success:
                break
            case .accessibilityDenied:
                deniedCount += 1
            case .failure:
                failedCount += 1
            }
        }

        if deniedCount > 0 {
            requestAccessibilityPermissionIfNeeded(for: "recall groups")
            return
        }

        if failedCount > 0 {
            notifyUser("SnapGroup could not raise \(failedCount) window(s) in Group \(group).")
        }
    }

    // The Magic Z-Order Jump
    private func bringWindowToFront(_ window: AXUIElement) -> RaiseWindowResult {
        // Get the Process ID (PID) of the app owning the window
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(window, &pid)
        guard pidResult == .success, pid != 0 else {
            if isAccessibilityError(pidResult) {
                return .accessibilityDenied
            }
            print("Failed to resolve owning app for window")
            return .failure
        }

        // Activate that App
        var didActivate = true
        if let app = NSRunningApplication(processIdentifier: pid) {
            didActivate = app.activate(options: .activateIgnoringOtherApps)
        }

        // Tell accessibility to "Raise" the specific window
        let result = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if isAccessibilityError(result) {
            return .accessibilityDenied
        }

        if result != .success {
            print("Failed to raise window (AX error: \(result.rawValue))")
            return .failure
        }

        if !didActivate {
            print("Failed to activate app for window")
            return .failure
        }

        return .success
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
            // Clean up invalid windows before reporting, but don't publish callbacks from a read path.
            cleanupInvalidWindows(in: i, notifyChange: false)
            info[i] = groups[i]?.count ?? 0
        }
        return info
    }

    // Get window titles in a group (for menu display)
    func getWindowTitles(forGroup group: Int) -> [String] {
        guard let windows = groups[group] else { return [] }

        return windows.map { window -> String in
            var titleValue: AnyObject?
            guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success else {
                return "(untitled)"
            }
            let title = (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return title.isEmpty ? "(untitled)" : title
        }
    }
}
