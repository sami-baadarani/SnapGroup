//
//  HotkeySettings.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import HotKey

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32  // NSEvent.ModifierFlags raw value

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }

    var key: Key? {
        Key(carbonKeyCode: keyCode)
    }

    // Convert to display string (e.g., "⌃⇧1")
    var displayString: String {
        var result = ""

        // Order: Control, Option, Shift, Command (standard macOS order)
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }

        // Add key name
        if let key = key {
            result += keyDisplayName(for: key)
        } else {
            result += "Key\(keyCode)"
        }

        return result
    }

    private func keyDisplayName(for key: Key) -> String {
        switch key {
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .space: return "Space"
        case .return: return "↩"
        case .tab: return "⇥"
        case .escape: return "⎋"
        case .delete: return "⌫"
        case .forwardDelete: return "⌦"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        default: return "?"
        }
    }
}

class HotkeySettings {
    static let shared = HotkeySettings()

    private let recallKey = "SnapGroup.recallBindings.v2"
    private let tagKey = "SnapGroup.tagBindings.v2"
    private let disabledRecallKey = "SnapGroup.disabledRecallGroups.v1"
    private let disabledTagKey = "SnapGroup.disabledTagGroups.v1"
    private let validGroups = 1...5

    private(set) var recallBindings: [Int: HotkeyBinding] = [:]
    private(set) var tagBindings: [Int: HotkeyBinding] = [:]
    private var disabledRecallGroups: Set<Int> = []
    private var disabledTagGroups: Set<Int> = []

    // Callback when settings change
    var onSettingsChanged: (() -> Void)?

    private init() {
        load()
    }

    // Default bindings: Ctrl+[1-5] for recall, Ctrl+Shift+[1-5] for tag
    func getDefaultRecallBinding(for group: Int) -> HotkeyBinding {
        let keyCode: UInt32 = switch group {
        case 1: 18  // Key.one
        case 2: 19  // Key.two
        case 3: 20  // Key.three
        case 4: 21  // Key.four
        case 5: 23  // Key.five (note: 5 is keycode 23, not 22)
        default: 18
        }
        return HotkeyBinding(
            keyCode: keyCode,
            modifiers: UInt32(NSEvent.ModifierFlags.control.rawValue)
        )
    }

    func getDefaultTagBinding(for group: Int) -> HotkeyBinding {
        let keyCode: UInt32 = switch group {
        case 1: 18
        case 2: 19
        case 3: 20
        case 4: 21
        case 5: 23  // Key.five (note: 5 is keycode 23, not 22)
        default: 18
        }
        return HotkeyBinding(
            keyCode: keyCode,
            modifiers: UInt32(NSEvent.ModifierFlags([.control, .shift]).rawValue)
        )
    }

    func resetToDefaults() {
        disabledRecallGroups.removeAll()
        disabledTagGroups.removeAll()

        for i in validGroups {
            recallBindings[i] = getDefaultRecallBinding(for: i)
            tagBindings[i] = getDefaultTagBinding(for: i)
        }
        save()
        onSettingsChanged?()
    }

    func save() {
        let encoder = JSONEncoder()

        if let recallData = try? encoder.encode(recallBindings) {
            UserDefaults.standard.set(recallData, forKey: recallKey)
        }

        if let tagData = try? encoder.encode(tagBindings) {
            UserDefaults.standard.set(tagData, forKey: tagKey)
        }

        if let disabledRecallData = try? encoder.encode(Array(disabledRecallGroups).sorted()) {
            UserDefaults.standard.set(disabledRecallData, forKey: disabledRecallKey)
        }

        if let disabledTagData = try? encoder.encode(Array(disabledTagGroups).sorted()) {
            UserDefaults.standard.set(disabledTagData, forKey: disabledTagKey)
        }

        print("Hotkey settings saved")
    }

    func load() {
        let decoder = JSONDecoder()

        if let recallData = UserDefaults.standard.data(forKey: recallKey),
           let decoded = try? decoder.decode([Int: HotkeyBinding].self, from: recallData) {
            recallBindings = decoded
        }

        if let tagData = UserDefaults.standard.data(forKey: tagKey),
           let decoded = try? decoder.decode([Int: HotkeyBinding].self, from: tagData) {
            tagBindings = decoded
        }

        if let disabledRecallData = UserDefaults.standard.data(forKey: disabledRecallKey),
           let decoded = try? decoder.decode([Int].self, from: disabledRecallData) {
            disabledRecallGroups = Set(decoded)
        }

        if let disabledTagData = UserDefaults.standard.data(forKey: disabledTagKey),
           let decoded = try? decoder.decode([Int].self, from: disabledTagData) {
            disabledTagGroups = Set(decoded)
        }

        // Drop unknown groups to keep persistence clean.
        recallBindings = recallBindings.filter { validGroups.contains($0.key) }
        tagBindings = tagBindings.filter { validGroups.contains($0.key) }
        disabledRecallGroups = Set(disabledRecallGroups.filter { validGroups.contains($0) })
        disabledTagGroups = Set(disabledTagGroups.filter { validGroups.contains($0) })

        // Fill in missing bindings with defaults unless explicitly disabled by the user.
        for i in validGroups {
            if recallBindings[i] == nil && !disabledRecallGroups.contains(i) {
                recallBindings[i] = getDefaultRecallBinding(for: i)
            }
            if tagBindings[i] == nil && !disabledTagGroups.contains(i) {
                tagBindings[i] = getDefaultTagBinding(for: i)
            }
        }

        print("Hotkey settings loaded")
    }

    func setRecallBinding(_ binding: HotkeyBinding?, for group: Int) {
        guard validGroups.contains(group) else { return }

        if let binding {
            recallBindings[group] = binding
            disabledRecallGroups.remove(group)
        } else {
            recallBindings.removeValue(forKey: group)
            disabledRecallGroups.insert(group)
        }

        save()
        onSettingsChanged?()
    }

    func setTagBinding(_ binding: HotkeyBinding?, for group: Int) {
        guard validGroups.contains(group) else { return }

        if let binding {
            tagBindings[group] = binding
            disabledTagGroups.remove(group)
        } else {
            tagBindings.removeValue(forKey: group)
            disabledTagGroups.insert(group)
        }

        save()
        onSettingsChanged?()
    }

    // Check for conflicts with system hotkeys
    func isSystemConflict(_ binding: HotkeyBinding) -> String? {
        let cmd = NSEvent.ModifierFlags.command.rawValue
        let shift = NSEvent.ModifierFlags.shift.rawValue

        // Cmd+Shift+3/4/5/6 are screenshot shortcuts
        if binding.modifiers == UInt32(cmd | shift) {
            switch binding.keyCode {
            case 20: return "Cmd+Shift+3 is used for screenshots"
            case 21: return "Cmd+Shift+4 is used for screenshots"
            case 23: return "Cmd+Shift+5 is used for screenshots"
            case 22: return "Cmd+Shift+6 is used for Touch Bar screenshots"
            default: break
            }
        }

        return nil
    }

    // Check for conflicts with other bindings in this app
    func isInternalConflict(_ binding: HotkeyBinding, excludingRecallGroup: Int? = nil, excludingTagGroup: Int? = nil) -> String? {
        for (group, existingBinding) in recallBindings {
            if group != excludingRecallGroup && existingBinding == binding {
                return "Already used for Recall Group \(group)"
            }
        }

        for (group, existingBinding) in tagBindings {
            if group != excludingTagGroup && existingBinding == binding {
                return "Already used for Tag Group \(group)"
            }
        }

        return nil
    }
}
