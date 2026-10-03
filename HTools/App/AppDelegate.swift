import AppKit
import SwiftUI

extension Notification.Name {
    static let showHToolsPermissions = Notification.Name("showHToolsPermissions")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: SettingsModel!
    private var permissions: PermissionsModel!
    private var keyboard: KeyboardControlModel!
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?
    private var notifications: [NSObjectProtocol] = []
    private var workspaceNotifications: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit-test hosts must not control Finder, install monitors or show UI.
        guard NSClassFromString("XCTestCase") == nil else { return }
        NSApp.setActivationPolicy(.accessory)
        PreferencesStore.migrateLegacyPreferences()
        permissions = PermissionsModel()
        model = SettingsModel()
        keyboard = KeyboardControlModel()
        permissions.beforeServiceChange = { [weak self] in self?.keyboard.disable() }
        permissions.start()
        keyboard.start()
        menuBar = MenuBarController(showSettings: { [weak self] in self?.showSettings() },
                                    showPermissions: { [weak self] in self?.showPermissions() })
        installApplicationMenu()
        model.start()
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.model.updateDisplays() })
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.model.service.refresh(); self?.permissions.refresh() })
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            workspaceNotifications.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.model.service.refresh(); self?.permissions.refresh() })
        }
        if !permissions.setupCompleted || !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--settings") {
            showSettings(); UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model, keyboard: keyboard, permissions: permissions))
            let window = NSWindow(contentViewController: hosting)
            window.title = "HTools"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.collectionBehavior = [.fullScreenNone]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
        model.service.refresh()
        permissions.refresh()
    }

    private func showPermissions() {
        showSettings()
        NotificationCenter.default.post(name: .showHToolsPermissions, object: nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { model.prepareToClose() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model != nil else { return .terminateNow }
        if permissions.busy {
            showPermissions()
            let alert = NSAlert()
            alert.messageText = "系统授权正在进行"
            alert.informativeText = "请先完成或取消系统授权，再退出 HTools。"
            alert.addButton(withTitle: "好"); alert.runModal()
            return .terminateCancel
        }
        if !model.prepareToClose() { showSettings(); return .terminateCancel }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceNotifications.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        permissions?.stop()
        keyboard?.stop()
        model?.service.stop()
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let app = NSMenuItem(); let submenu = NSMenu()
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self; submenu.addItem(settings)
        let permissionItem = NSMenuItem(title: "权限设置…", action: #selector(openPermissions), keyEquivalent: "")
        permissionItem.target = self; submenu.addItem(permissionItem)
        submenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "退出 HTools", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        app.submenu = submenu; main.addItem(app)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        edit.submenu = editMenu; main.addItem(edit)
        NSApp.mainMenu = main
    }
    @objc private func openPermissions() { showPermissions() }
    @objc private func openSettings() { showSettings() }
}
