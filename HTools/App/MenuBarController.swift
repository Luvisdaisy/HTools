import AppKit

final class MenuBarController: NSObject {
    private let showSettings: () -> Void
    private let toggleSettings: () -> Void
    private let menu = NSMenu()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(showSettings: @escaping () -> Void, toggleSettings: @escaping () -> Void) {
        self.showSettings = showSettings
        self.toggleSettings = toggleSettings
        super.init()
        let icon = NSImage(named: "MenuBarIcon")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.setAccessibilityLabel("HTools")
        statusItem.button?.toolTip = "HTools"
        let settings = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "退出", action: #selector(terminate), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        menu.showsStateColumn = false
        for item in menu.items {
            item.image = nil
            item.keyEquivalentModifierMask = []
            // Xcode 26 remains supported; this property first appears in the 27 SDK.
            #if compiler(>=6.4)
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .hidden
            }
            #endif
        }
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    var anchorButton: NSStatusBarButton? { statusItem.button }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            // Attach only during tracking so ordinary clicks open the panel directly.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleSettings()
        }
    }

    @objc private func openSettings() { showSettings() }
    @objc private func terminate() { NSApp.terminate(nil) }
}
