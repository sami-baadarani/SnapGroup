//
//  AppDelegate.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import HotKey

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let groupManager = GroupManager()
    var menuBarController: MenuBarController!
    var hotKeys: [HotKey] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Check for Accessibility Permissions on launch
        if !groupManager.checkPermissions() {
            print("Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
        }

        // Setup menu bar
        menuBarController = MenuBarController(groupManager: groupManager)

        // Setup hotkeys
        setupHotkeys()

        print("SnapGroup is running. Use Cmd+Shift+[1-5] to tag windows, Cmd+[1-5] to recall.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup hotkeys
        hotKeys.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func setupHotkeys() {
        // Loop for groups 1 to 5
        for i in 1...5 {
            let key = keyForNumber(i)

            // RECALL: Command + Number
            let recallHotKey = HotKey(key: key, modifiers: [.command])
            recallHotKey.keyDownHandler = { [weak self] in
                self?.groupManager.recallGroup(i)
            }
            hotKeys.append(recallHotKey)

            // TAG: Command + Shift + Number
            let tagHotKey = HotKey(key: key, modifiers: [.command, .shift])
            tagHotKey.keyDownHandler = { [weak self] in
                self?.groupManager.tagWindow(toGroup: i)
            }
            hotKeys.append(tagHotKey)
        }
    }

    // Helper to map integers to Key enums (from HotKey library)
    private func keyForNumber(_ num: Int) -> Key {
        switch num {
        case 1: return .one
        case 2: return .two
        case 3: return .three
        case 4: return .four
        case 5: return .five
        default: return .one
        }
    }
}
