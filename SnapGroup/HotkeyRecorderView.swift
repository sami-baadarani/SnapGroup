//
//  HotkeyRecorderView.swift
//  SnapGroup
//
//  Created by Sami Baadarani on 25/12/2025.
//

import Cocoa
import Carbon

class HotkeyRecorderView: NSView {
    private var isRecording = false
    private var currentBinding: HotkeyBinding?
    private var eventMonitor: Any?

    var binding: HotkeyBinding? {
        get { currentBinding }
        set {
            currentBinding = newValue
            needsDisplay = true
        }
    }

    // Callback when binding changes
    var onBindingChanged: ((HotkeyBinding?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()
    }

    private func updateAppearance() {
        if isRecording {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text: String
        let textColor: NSColor

        if isRecording {
            text = "Press keys..."
            textColor = .controlAccentColor
        } else if let binding = currentBinding {
            text = binding.displayString
            textColor = .labelColor
        } else {
            text = "Click to set"
            textColor = .secondaryLabelColor
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )

        text.draw(at: point, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        updateAppearance()
        window?.makeFirstResponder(self)

        // Add local event monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil  // Consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        updateAppearance()

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {  // Escape key
            stopRecording()
            return
        }

        // Delete/Backspace clears the binding
        if event.keyCode == 51 || event.keyCode == 117 {  // Delete or Forward Delete
            currentBinding = nil
            onBindingChanged?(nil)
            stopRecording()
            return
        }

        // Ignore pure modifier key presses (wait for actual key)
        if event.type == .flagsChanged {
            return
        }

        // Get modifiers (filter out non-modifier flags)
        let modifierMask: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let modifiers = event.modifierFlags.intersection(modifierMask)

        // Require at least one modifier for a valid hotkey
        if modifiers.isEmpty {
            NSSound.beep()
            return
        }

        let newBinding = HotkeyBinding(
            keyCode: UInt32(event.keyCode),
            modifiers: UInt32(modifiers.rawValue)
        )

        // Check for system conflicts
        if let conflict = HotkeySettings.shared.isSystemConflict(newBinding) {
            showConflictAlert(conflict) { [weak self] proceed in
                if proceed {
                    self?.acceptBinding(newBinding)
                } else {
                    self?.stopRecording()
                }
            }
            return
        }

        acceptBinding(newBinding)
    }

    private func acceptBinding(_ binding: HotkeyBinding) {
        currentBinding = binding
        onBindingChanged?(binding)
        stopRecording()
    }

    private func showConflictAlert(_ message: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Hotkey Conflict"
        alert.informativeText = "\(message)\n\nDo you want to use this hotkey anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Use Anyway")
        alert.addButton(withTitle: "Cancel")

        if let window = window {
            alert.beginSheetModal(for: window) { response in
                completion(response == .alertFirstButtonReturn)
            }
        } else {
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }

    func clear() {
        currentBinding = nil
        onBindingChanged?(nil)
        needsDisplay = true
    }

    // Cancel recording if view loses focus
    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }
}
