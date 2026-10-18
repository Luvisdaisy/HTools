// Offline render of actual SwiftUI components; never starts HID or Finder control.
// Uses isolated preferences and sample state, not a desktop screenshot.
import AppKit
import SwiftUI
import ServiceManagement

private struct PreviewLoginItemService: LoginItemServicing {
    var status: SMAppService.Status
    var registrationFails = false
    func register() throws {
        if registrationFails {
            throw NSError(domain: "HTools.preview", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "系统未能注册登录项，请将 HTools 放入应用程序并检查系统登录项设置后重试。"])
        }
    }
    func unregister() throws {}
    func openSettings() {}
}

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
        try FileManager.default.createDirectory(atPath: "docs/images", withIntermediateDirectories: true)
        for (name, page) in [("general", SettingsPage.general), ("general-approval", .general), ("general-error", .general), ("general-error-dark", .general), ("general-dark", .general), ("permissions", .permissions), ("permissions-ready", .permissions), ("finder", .finder), ("finder-invalid", .finder), ("keyboard", .keyboard), ("keyboard-no-external", .keyboard), ("keyboard-disabled", .keyboard), ("keyboard-gate", .keyboard), ("keyboard-dark", .keyboard)] {
            let permissions = PermissionsModel.preview(defaults: defaults, ready: name != "permissions" && name != "keyboard-gate")
            model.resetDraft()
            if name == "finder-invalid" { model.widthText = "50" }
            let loginItem = LoginItemModel(service: PreviewLoginItemService(
                status: name == "general-approval" ? .requiresApproval : .notRegistered,
                registrationFails: name.contains("error")))
            if name.contains("error") { loginItem.setEnabled(true) }
            let keyboard = KeyboardControlModel.preview(
                externalConnected: name != "keyboard-no-external" && name != "keyboard-disabled",
                disabled: name == "keyboard-disabled")
            let content = SettingsView(model: model, keyboard: keyboard, permissions: permissions, loginItem: loginItem, initialPage: page)
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
