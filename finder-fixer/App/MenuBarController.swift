import AppKit

final class MenuBarController: NSObject {
    private let showSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(showSettings: @escaping () -> Void) {
        self.showSettings = showSettings
        super.init()
        let icon = NSImage(named: "MenuBarIcon")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = false
        statusItem.button?.image = icon
        statusItem.button?.setAccessibilityLabel("finder-fixer")
        statusItem.button?.toolTip = "finder-fixer"
        let menu = NSMenu()
        let settings = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(terminate), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func openSettings() { showSettings() }
    @objc private func terminate() { NSApp.terminate(nil) }
}
