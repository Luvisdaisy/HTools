import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: SettingsModel!
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?
    private var notifications: [NSObjectProtocol] = []
    private var workspaceNotifications: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit-test hosts must not control Finder, install monitors or show UI.
        guard NSClassFromString("XCTestCase") == nil else { return }
        NSApp.setActivationPolicy(.accessory)
        model = SettingsModel()
        menuBar = MenuBarController() { [weak self] in self?.showSettings() }
        installApplicationMenu()
        model.start()
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.model.updateDisplays() })
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.model.service.refresh() })
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            workspaceNotifications.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.model.service.refresh() })
        }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--settings") {
            showSettings(); UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "finder-fixer"
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
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { model.prepareToClose() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model != nil else { return .terminateNow }
        if !model.prepareToClose() { showSettings(); return .terminateCancel }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceNotifications.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        model?.service.stop()
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let app = NSMenuItem(); let submenu = NSMenu()
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self; submenu.addItem(settings)
        submenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "退出 finder-fixer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        app.submenu = submenu; main.addItem(app)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        edit.submenu = editMenu; main.addItem(edit)
        NSApp.mainMenu = main
    }
    @objc private func openSettings() { showSettings() }
}
