// Offline render of actual SwiftUI components; never starts HID or Finder control.
// Uses isolated preferences and sample state, not a desktop screenshot.
import AppKit
import SwiftUI

@main
struct PreviewRenderer {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.applicationIconImage = NSImage(contentsOfFile: "assets/app-icon.png")
        let domain = "HTools.preview.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let model = SettingsModel(store: PreferencesStore(defaults: defaults))
        model.service.onStatus?(FinderServiceStatus(trusted: true))
        let keyboard = KeyboardControlModel.preview()
        try FileManager.default.createDirectory(atPath: "docs/images", withIntermediateDirectories: true)
        for (name, page) in [("permissions", SettingsPage.permissions), ("permissions-ready", .permissions), ("finder", .finder), ("finder-invalid", .finder), ("keyboard", .keyboard), ("keyboard-gate", .keyboard), ("keyboard-dark", .keyboard)] {
            let permissions = PermissionsModel.preview(defaults: defaults, ready: name != "permissions" && name != "keyboard-gate")
            model.resetDraft()
            if name == "finder-invalid" { model.widthText = "50" }
            let content = SettingsView(model: model, keyboard: keyboard, permissions: permissions, initialPage: page)
            let host = NSHostingView(rootView: content)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: name.hasSuffix("dark") ? .darkAqua : .aqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No bitmap") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
            try data.write(to: URL(fileURLWithPath: "docs/images/\(name).png"))
            print("Rendered \(name): \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
        }
    }
}
