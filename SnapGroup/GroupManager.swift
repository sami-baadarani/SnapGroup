//
//  GroupManager.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import ApplicationServices

class GroupManager {
    private struct TrackedWindow {
        let element: AXUIElement
        let title: String
        let pid: pid_t
    }

    private var groups: [Int: [TrackedWindow]] = [:]
    private var hasPromptedForAccessibilityThisSession = false
    private var cachedPermissionGranted = false
    private var cachedPermissionTimestamp: Date = .distantPast

    // Proactive AXEnhancedUserInterface signaling for Chromium-based browsers.
    // Tracks PIDs we've already signaled to avoid resetting Chromium's 2-second debounce.
    private var enhancedUIPids: Set<pid_t> = []
    private var workspaceObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?

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
        // Fast check: is the owning process still alive?
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid > 0 else {
            return false
        }
        guard NSRunningApplication(processIdentifier: pid) != nil else {
            return false
        }

        var roleValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue)

        if result == .success {
            return (roleValue as? String) == (kAXWindowRole as String)
        }
        // Process alive but AX transiently unavailable — keep the window
        if result == .cannotComplete || result == .apiDisabled {
            return true
        }
        return false
    }

    // Clean up invalid windows from a group
    private func cleanupInvalidWindows(in group: Int, notifyChange: Bool = true) {
        guard var windows = groups[group] else { return }
        let originalCount = windows.count
        windows = windows.filter { isWindowValid($0.element) }
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

    // Signal Chromium-based browsers (Brave, Chrome, Edge) to enable their
    // Accessibility API. Non-Chromium apps simply ignore this attribute.
    private func enableEnhancedUI(for app: AXUIElement) {
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
    }

    /// Proactively set AXEnhancedUserInterface when apps come to foreground,
    /// so Chromium's 2-second debounce has elapsed by the time the user presses a hotkey.
    func startObservingAppActivations() {
        let ws = NSWorkspace.shared

        // Signal the current frontmost app immediately
        if let frontmost = ws.frontmostApplication {
            let pid = frontmost.processIdentifier
            if pid > 0, enhancedUIPids.insert(pid).inserted {
                let app = AXUIElementCreateApplication(pid)
                enableEnhancedUI(for: app)
            }
        }

        workspaceObserver = ws.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            guard pid > 0 else { return }
            // Only signal each PID once to avoid resetting the debounce
            if self.enhancedUIPids.insert(pid).inserted {
                let axApp = AXUIElementCreateApplication(pid)
                self.enableEnhancedUI(for: axApp)
            }
        }

        terminationObserver = ws.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.enhancedUIPids.remove(app.processIdentifier)
        }
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

    // Get the focused window, retrying on transient AX errors or missing focus during transitions.
    private func getFocusedWindow() -> FocusedWindowLookupResult {
        for attempt in 0..<3 {
            let result = getFocusedWindowOnce()
            switch result {
            case .success:
                return result
            case .accessibilityDenied:
                return result
            case .noFocusedWindow:
                // Could be transient during focus transitions — retry
                if attempt < 2 {
                    Thread.sleep(forTimeInterval: 0.05)
                    continue
                }
                return result
            case .failure(let error):
                if (error == .cannotComplete || error == .apiDisabled),
                   isPermissionGranted(), attempt < 2 {
                    print("[SnapGroup] Retrying after transient AX error \(error.rawValue)")
                    Thread.sleep(forTimeInterval: 0.1)
                    continue
                }
                return result
            }
        }
        return .noFocusedWindow
    }

    // Get the focused window with fallbacks for Chromium-based browsers.
    // Fallback A: If kAXFocusedApplicationAttribute fails, use NSWorkspace.frontmostApplication.
    // Fallback B: If kAXFocusedWindowAttribute returns nil, query kAXWindowsAttribute and pick the main window.
    private func getFocusedWindowOnce() -> FocusedWindowLookupResult {
        let systemWide = AXUIElementCreateSystemWide()
        let myPid = ProcessInfo.processInfo.processIdentifier

        // --- Resolve the focused app (with frontmostApplication fallback) ---
        var appPid: pid_t = 0
        var app: AXUIElement

        var focusedAppValue: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)

        if appResult == .success, let focusedAppValue {
            app = focusedAppValue as! AXUIElement
            AXUIElementGetPid(app, &appPid)
        } else {
            // Fallback A: AX system-wide query failed — try NSWorkspace
            if isAccessibilityError(appResult) {
                return .accessibilityDenied
            }
            guard let frontmost = NSWorkspace.shared.frontmostApplication else {
                return .noFocusedWindow
            }
            appPid = frontmost.processIdentifier
            guard appPid > 0 else { return .noFocusedWindow }
            app = AXUIElementCreateApplication(appPid)
        }

        // Skip SnapGroup itself — let retry logic wait for focus to return to the user's window
        if appPid == myPid {
            return .noFocusedWindow
        }

        // Debounce-safe: only signal if we haven't already
        if enhancedUIPids.insert(appPid).inserted {
            enableEnhancedUI(for: app)
        }

        // --- Resolve the focused window (with kAXWindowsAttribute fallback) ---
        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        if windowResult == .success, let focusedWindow {
            return .success(focusedWindow as! AXUIElement)
        }

        // Check for hard errors before trying fallback
        if windowResult != .success && windowResult != .noValue {
            if isAccessibilityError(windowResult) {
                return .accessibilityDenied
            }
        }

        // Fallback B: query all windows and pick the main one
        var windowList: AnyObject?
        let listResult = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowList)
        guard listResult == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty else {
            if windowResult == .noValue || listResult == .noValue {
                return .noFocusedWindow
            }
            return .failure(windowResult)
        }

        // Prefer the window with kAXMainAttribute = true
        for window in windows {
            var mainValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMainAttribute as CFString, &mainValue) == .success,
               CFBooleanGetValue(mainValue as! CFBoolean) {
                return .success(window)
            }
        }

        // Fall back to the first window with a proper role
        for window in windows {
            var roleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue) == .success,
               (roleValue as? String) == (kAXWindowRole as String) {
                return .success(window)
            }
        }

        // Last resort: first window in the list
        return .success(windows[0])
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

        // Capture window metadata now so menu updates never need live AX queries
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        let title = (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        // Initialize array if nil
        if groups[group] == nil { groups[group] = [] }

        // Check for duplicates
        let exists = groups[group]?.contains(where: { CFEqual($0.element, window) }) ?? false

        if !exists {
            let tracked = TrackedWindow(element: window, title: title, pid: pid)
            groups[group]?.append(tracked)
            print("Tagged '\(title.isEmpty ? "(untitled)" : title)' to Group \(group)")
            onGroupsChanged?()
        } else {
            print("Window '\(title.isEmpty ? "(untitled)" : title)' already in Group \(group)")
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
        windows = windows.filter { !CFEqual($0.element, window) }

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
        for tracked in windows {
            switch bringWindowToFront(tracked.element) {
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

        // Debounce-safe: only signal if we haven't already
        let appElement = AXUIElementCreateApplication(pid)
        if enhancedUIPids.insert(pid).inserted {
            enableEnhancedUI(for: appElement)
        }

        // Tell the app which window should be main before activating (Hammerspoon pattern)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFTypeRef)

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

    // Get group info for menu bar display (fast PID-only prune, no AX queries)
    func getGroupInfo() -> [Int: Int] {
        var info: [Int: Int] = [:]
        for i in 1...5 {
            if var windows = groups[i] {
                let before = windows.count
                windows = windows.filter { NSRunningApplication(processIdentifier: $0.pid) != nil }
                if windows.count != before {
                    groups[i] = windows
                }
            }
            info[i] = groups[i]?.count ?? 0
        }
        return info
    }

    // Get window titles in a group (uses cached titles, no live AX queries)
    func getWindowTitles(forGroup group: Int) -> [String] {
        guard let windows = groups[group] else { return [] }
        return windows.map { $0.title.isEmpty ? "(untitled)" : $0.title }
    }
}
