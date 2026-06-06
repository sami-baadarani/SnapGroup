//
//  MenuBarController.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import Sparkle

class MenuBarController {
    private var statusItem: NSStatusItem!
    private let groupManager: GroupManager
    private weak var appDelegate: AppDelegate?
    private let updaterController: SPUStandardUpdaterController
    private var isUpdatingMenu = false

    init(groupManager: GroupManager, appDelegate: AppDelegate, updaterController: SPUStandardUpdaterController) {
        self.groupManager = groupManager
        self.appDelegate = appDelegate
        self.updaterController = updaterController
        setupStatusItem()

        // Subscribe to group changes
        groupManager.onGroupsChanged = { [weak self] in
            self?.updateMenu()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
        }

        updateMenu()
    }

    func updateMenu() {
        guard !isUpdatingMenu else { return }
        isUpdatingMenu = true
        defer { isUpdatingMenu = false }

        let menu = NSMenu()
        let settings = HotkeySettings.shared

        // Header
        let headerItem = NSMenuItem(title: "SnapGroup", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // Groups 1-5
        let groupInfo = groupManager.getGroupInfo()
        for i in 1...5 {
            let count = groupInfo[i] ?? 0
            let groupItem = NSMenuItem(
                title: "Group \(i): \(count) window\(count == 1 ? "" : "s")",
                action: nil,
                keyEquivalent: ""
            )

            // Create submenu for groups with windows
            if count > 0 {
                let submenu = NSMenu()

                // Show window titles
                let titles = groupManager.getWindowTitles(forGroup: i)
                for title in titles {
                    let windowItem = NSMenuItem(title: title.isEmpty ? "(untitled)" : title, action: nil, keyEquivalent: "")
                    windowItem.isEnabled = false
                    submenu.addItem(windowItem)
                }

                submenu.addItem(NSMenuItem.separator())

                // Recall action with dynamic hotkey
                let recallHotkey = settings.recallBindings[i]?.displayString ?? "Not set"
                let recallItem = NSMenuItem(title: "Recall (\(recallHotkey))", action: #selector(recallGroup(_:)), keyEquivalent: "")
                recallItem.target = self
                recallItem.tag = i
                submenu.addItem(recallItem)

                // Clear action
                let clearItem = NSMenuItem(title: "Clear Group", action: #selector(clearGroup(_:)), keyEquivalent: "")
                clearItem.target = self
                clearItem.tag = i
                submenu.addItem(clearItem)

                groupItem.submenu = submenu
            } else {
                groupItem.isEnabled = false
            }

            menu.addItem(groupItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Hotkey help - show current bindings
        let helpItem = NSMenuItem(title: "Hotkeys", action: nil, keyEquivalent: "")
        helpItem.isEnabled = false
        menu.addItem(helpItem)

        // Show first recall/tag binding as example
        let recallExample = settings.recallBindings[1]?.displayString ?? "Not set"
        let tagExample = settings.tagBindings[1]?.displayString ?? "Not set"

        let recallHelpItem = NSMenuItem(title: "  Recall: \(recallExample)...", action: nil, keyEquivalent: "")
        recallHelpItem.isEnabled = false
        menu.addItem(recallHelpItem)

        let tagHelpItem = NSMenuItem(title: "  Tag: \(tagExample)...", action: nil, keyEquivalent: "")
        tagHelpItem.isEnabled = false
        menu.addItem(tagHelpItem)

        menu.addItem(NSMenuItem.separator())

        // Clear all
        let clearAllItem = NSMenuItem(title: "Clear All Groups", action: #selector(clearAllGroups), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Settings...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        // About
        let aboutItem = NSMenuItem(title: "About SnapGroup", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Check for Updates
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit SnapGroup", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func recallGroup(_ sender: NSMenuItem) {
        groupManager.recallGroup(sender.tag)
    }

    @objc private func clearGroup(_ sender: NSMenuItem) {
        groupManager.clearGroup(sender.tag)
    }

    @objc private func clearAllGroups() {
        let alert = NSAlert()
        alert.messageText = "Clear All Groups?"
        alert.informativeText = "This will remove all windows from all groups. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            groupManager.clearAllGroups()
        }
    }

    @objc private func showPreferences() {
        appDelegate?.showPreferences()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
