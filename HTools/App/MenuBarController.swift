import AppKit

final class MenuBarController: NSObject {
    private let showPermissions: () -> Void
    private let showSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(showSettings: @escaping () -> Void, showPermissions: @escaping () -> Void) {
        self.showSettings = showSettings
        self.showPermissions = showPermissions
        super.init()
        let icon = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "HTools")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.setAccessibilityLabel("HTools")
        statusItem.button?.toolTip = "HTools"
        let menu = NSMenu()
        let settings = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let permissions = NSMenuItem(title: "权限设置…", action: #selector(openPermissions), keyEquivalent: "")
        permissions.target = self; menu.addItem(permissions)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(terminate), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func openPermissions() { showPermissions() }
    @objc private func openSettings() { showSettings() }
    @objc private func terminate() { NSApp.terminate(nil) }
}
