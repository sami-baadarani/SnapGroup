//
//  MenuBarController.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa

class MenuBarController {
    private var statusItem: NSStatusItem!
    private let groupManager: GroupManager
    private weak var appDelegate: AppDelegate?
    private var isUpdatingMenu = false

    init(groupManager: GroupManager, appDelegate: AppDelegate) {
        self.groupManager = groupManager
        self.appDelegate = appDelegate
        setupStatusItem()

        // Subscribe to group changes
        groupManager.onGroupsChanged = { [weak self] in
            self?.updateMenu()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "SnapGroup")
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
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

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
        groupManager.clearAllGroups()
    }

    @objc private func showPreferences() {
        appDelegate?.showPreferences()
    }
}
