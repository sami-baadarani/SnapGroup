//
//  AppDelegate.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import HotKey
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    let groupManager = GroupManager()
    var menuBarController: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!
    var hotKeys: [HotKey] = []
    private var isPresentingAlert = false
    private var lastHotkeyWarningSignature: String?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Check permission status on launch, but request on-demand from real AX failures.
        if !groupManager.checkPermissions(prompt: false) {
            debugLog("Accessibility permission not confirmed at launch. SnapGroup will request it when needed.")
        }

        // Proactively signal AXEnhancedUserInterface to apps as they activate,
        // so Chromium's 2-second debounce has elapsed by the time the user presses a hotkey.
        groupManager.startObservingAppActivations()

        // Setup preferences window controller
        preferencesWindowController = PreferencesWindowController()

        // Setup menu bar (pass self for preferences action)
        menuBarController = MenuBarController(groupManager: groupManager, appDelegate: self, updaterController: updaterController)

        groupManager.onUserMessage = { [weak self] message in
            self?.showAlert(title: "SnapGroup", message: message)
        }

        // Subscribe to hotkey settings changes
        HotkeySettings.shared.onSettingsChanged = { [weak self] in
            self?.rebindHotkeys()
            self?.menuBarController.updateMenu()
        }

        // Setup hotkeys from settings
        rebindHotkeys()

        debugLog("SnapGroup is running. Use Ctrl+[1-5] to recall, Ctrl+Shift+[1-5] to tag.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup hotkeys
        hotKeys.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func showPreferences() {
        preferencesWindowController.showWindow()
    }

    func rebindHotkeys() {
        // Clear existing hotkeys
        hotKeys.removeAll()

        let settings = HotkeySettings.shared
        var seenBindings: Set<String> = []
        var warnings: [String] = []

        func registerBinding(_ binding: HotkeyBinding?, group: Int, action: String, handler: @escaping () -> Void) {
            guard let binding else { return }

            let context = "\(action) Group \(group)"

            if let conflict = settings.isSystemConflict(binding) {
                warnings.append("\(context) skipped: \(conflict)")
                return
            }

            guard let key = binding.key else {
                warnings.append("\(context) skipped: Unsupported key code \(binding.keyCode)")
                return
            }

            let signature = "\(binding.keyCode)-\(binding.modifiers)"
            guard seenBindings.insert(signature).inserted else {
                warnings.append("\(context) skipped: duplicate shortcut")
                return
            }

            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(binding.modifiers))
            let hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey.keyDownHandler = handler
            hotKeys.append(hotKey)
        }

        // Register recall hotkeys
        for group in 1...5 {
            registerBinding(settings.recallBindings[group], group: group, action: "Recall") { [weak self] in
                self?.groupManager.recallGroup(group)
            }
        }

        // Register tag hotkeys
        for group in 1...5 {
            registerBinding(settings.tagBindings[group], group: group, action: "Tag") { [weak self] in
                self?.groupManager.tagWindow(toGroup: group)
            }
        }

        if !warnings.isEmpty {
            let signature = warnings.joined(separator: "|")
            if signature != lastHotkeyWarningSignature {
                lastHotkeyWarningSignature = signature
                showAlert(title: "Hotkey Issues", message: warnings.joined(separator: "\n"))
            }
            debugLog("Hotkey warnings:\n\(warnings.joined(separator: "\n"))")
        } else {
            lastHotkeyWarningSignature = nil
        }

        debugLog("Hotkeys rebound: \(hotKeys.count) active")
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.isPresentingAlert else { return }
            self.isPresentingAlert = true

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")

            NSApp.activate()
            alert.runModal()
            self.isPresentingAlert = false
        }
    }
}
