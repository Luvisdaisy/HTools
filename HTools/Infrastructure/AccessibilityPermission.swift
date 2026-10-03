import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static func openSettings() {
        // The OS owns the consent decision. This never changes the TCC database.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
