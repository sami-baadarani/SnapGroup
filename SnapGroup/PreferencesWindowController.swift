//
//  PreferencesWindowController.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    private var recallRecorders: [Int: HotkeyRecorderView] = [:]
    private var tagRecorders: [Int: HotkeyRecorderView] = [:]

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SnapGroup Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
        loadCurrentBindings()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        var yOffset: CGFloat = contentView.bounds.height - 40

        // Title
        let titleLabel = createLabel("Customize Hotkeys", bold: true)
        titleLabel.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        contentView.addSubview(titleLabel)
        yOffset -= 35

        // Recall section
        let recallHeader = createLabel("Recall Hotkeys", bold: true)
        recallHeader.frame = NSRect(x: 20, y: yOffset, width: 200, height: 18)
        contentView.addSubview(recallHeader)
        yOffset -= 8

        for i in 1...5 {
            yOffset -= 32
            let row = createHotkeyRow(group: i, isTag: false, yOffset: yOffset)
            contentView.addSubview(row)
        }

        yOffset -= 25

        // Tag section
        let tagHeader = createLabel("Tag Hotkeys", bold: true)
        tagHeader.frame = NSRect(x: 20, y: yOffset, width: 200, height: 18)
        contentView.addSubview(tagHeader)
        yOffset -= 8

        for i in 1...5 {
            yOffset -= 32
            let row = createHotkeyRow(group: i, isTag: true, yOffset: yOffset)
            contentView.addSubview(row)
        }

        yOffset -= 30

        // Buttons
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 20, y: 20, width: 140, height: 28)
        contentView.addSubview(resetButton)

        let doneButton = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.frame = NSRect(x: 280, y: 20, width: 100, height: 28)
        contentView.addSubview(doneButton)
    }

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }

    private func createHotkeyRow(group: Int, isTag: Bool, yOffset: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 20, y: yOffset, width: 360, height: 28))

        // Label
        let label = createLabel("Group \(group):")
        label.frame = NSRect(x: 0, y: 4, width: 70, height: 20)
        row.addSubview(label)

        // Recorder
        let recorder = HotkeyRecorderView(frame: NSRect(x: 80, y: 0, width: 120, height: 28))
        recorder.onBindingChanged = { [weak self] binding in
            self?.bindingChanged(group: group, isTag: isTag, binding: binding)
        }
        row.addSubview(recorder)

        if isTag {
            tagRecorders[group] = recorder
        } else {
            recallRecorders[group] = recorder
        }

        // Clear button
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearBinding(_:)))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: 210, y: 0, width: 60, height: 28)
        clearButton.tag = isTag ? (group + 100) : group  // Encode isTag in tag
        row.addSubview(clearButton)

        return row
    }

    private func loadCurrentBindings() {
        let settings = HotkeySettings.shared

        for i in 1...5 {
            recallRecorders[i]?.binding = settings.recallBindings[i]
            tagRecorders[i]?.binding = settings.tagBindings[i]
        }
    }

    private func bindingChanged(group: Int, isTag: Bool, binding: HotkeyBinding?) {
        let settings = HotkeySettings.shared

        // Check for internal conflicts
        if let binding = binding {
            let conflict = isTag
                ? settings.isInternalConflict(binding, excludingTagGroup: group)
                : settings.isInternalConflict(binding, excludingRecallGroup: group)

            if let conflict = conflict {
                showAlert(title: "Conflict", message: conflict)
                // Revert to previous binding
                if isTag {
                    tagRecorders[group]?.binding = settings.tagBindings[group]
                } else {
                    recallRecorders[group]?.binding = settings.recallBindings[group]
                }
                return
            }
        }

        // Save the binding
        if isTag {
            settings.setTagBinding(binding, for: group)
        } else {
            settings.setRecallBinding(binding, for: group)
        }
    }

    @objc private func clearBinding(_ sender: NSButton) {
        let tag = sender.tag
        let isTag = tag > 100
        let group = isTag ? (tag - 100) : tag

        if isTag {
            tagRecorders[group]?.clear()
        } else {
            recallRecorders[group]?.clear()
        }
    }

    @objc private func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults?"
        alert.informativeText = "This will reset all hotkeys to their default values."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if let window = window {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    HotkeySettings.shared.resetToDefaults()
                    self?.loadCurrentBindings()
                }
            }
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if let window = window {
            alert.beginSheetModal(for: window)
        }
    }

    func showWindow() {
        loadCurrentBindings()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
