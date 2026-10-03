import AppKit
import Combine
import IOKit.hidsystem

final class KeyboardControlModel: ObservableObject {
    enum State { case off, authorizing, on, stopping }
    @Published private(set) var devices: [KeyboardDevice] = []
    @Published private(set) var state: State = .off
    @Published var error: String?
    private let manager = HIDDeviceManager()
    private var listener: KeyboardListener?
    private var channel: KeyboardChannel?
    private var serviceConnection: NSXPCConnection?
    var openPermissions: () -> Void = {}
    private var timer: Timer?
    private var runID: UUID?
    private var selection: KeyboardSelection?
    private var lastResponse = ProcessInfo.processInfo.systemUptime
    private var observers: [NSObjectProtocol] = []

    var busy: Bool { state == .authorizing || state == .stopping }
    var canEnable: Bool { KeyboardSelection.resolve(devices) != nil }

    func start() {
        manager.changed = { [weak self] kind, device in
            guard let self else { return }
            self.refresh()
            if kind == "removed", device.registryID == self.selection?.externalID || device.registryID == self.selection?.internalID {
                self.disable()
            }
        }
        manager.failed = { [weak self] _ in
            self?.disable(); self?.error = "无法检测键盘，请重新启动 HTools。"
        }
        if manager.start() != 0 { error = "无法检测键盘，请检查系统权限后重新启动。" }
        refresh()
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.disable()
            })
        }
    }

    private func refresh() {
        devices = manager.devices.values.sorted {
            let left = $0.classification.role == .builtIn ? 0 : 1
            let right = $1.classification.role == .builtIn ? 0 : 1
            return left == right ? $0.registryID < $1.registryID : left < right
        }
    }

    func setDisabled(_ disabled: Bool) {
        if disabled { enable() } else { disable() }
    }

    private func enable() {
        guard state == .off, let selection = KeyboardSelection.resolve(devices) else { return }
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            openPermissions()
            return
        }
        error = nil; state = .authorizing; self.selection = selection
        let id = UUID(); runID = id
        do {
            let listener = try KeyboardListener(); self.listener = listener
            listener.accepted = { [weak self] channel in
                guard let self, self.runID == id, self.state == .authorizing else { channel.close(); return }
                self.listener?.close(); self.listener = nil
                self.channel = channel
                self.lastResponse = ProcessInfo.processInfo.systemUptime
                channel.received = { [weak self] line in self?.receive(line, id: id) }
                channel.disconnected = { [weak self] in
                    guard let self, self.runID == id else { return }
                    self.fail("键盘控制连接已结束，请确认内置键盘恢复后重试。")
                }
                channel.start()
                _ = channel.send("PING")
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    guard let self, self.runID == id else { return }
                    if ProcessInfo.processInfo.systemUptime - self.lastResponse > 3 {
                        self.fail("键盘控制没有响应，正在自动恢复内置键盘。")
                    } else { _ = self.channel?.send("PING") }
                }
                if let timer = self.timer { RunLoop.main.add(timer, forMode: .common) }
            }
            listener.start()
            let connection = try KeyboardServiceIdentity.connect()
            serviceConnection = connection
            let failed: () -> Void = { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.runID == id else { return }
                    self.fail("键盘控制服务不可用，请在权限设置中安装或更新服务。")
                    self.openPermissions()
                }
            }
            connection.invalidationHandler = failed
            connection.interruptionHandler = failed
            connection.resume()
            let remote = connection.remoteObjectProxyWithErrorHandler { _ in failed() } as? KeyboardServiceProtocol
            remote?.startSession(path: listener.path, internalID: selection.internalID, externalID: selection.externalID) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self, self.runID == id, let error else { return }
                    self.fail(error)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, self.runID == id, self.state == .authorizing else { return }
                self.fail("键盘服务连接超时，请在权限设置中检查服务。")
                self.openPermissions()
            }
        } catch { fail("无法启动键盘控制：\(error.localizedDescription)") }
    }

    private func receive(_ line: String, id: UUID) {
        guard runID == id else { return }
        lastResponse = ProcessInfo.processInfo.systemUptime
        switch line {
        case "PONG": break
        case "BLOCKED":
            if state == .authorizing { state = .on }
        case "RELEASED": cleanup(); state = .off
        default:
            if line.hasPrefix("ERROR:") { fail(String(line.dropFirst(6))) }
            else { fail("键盘控制返回了无效状态，已停止本次操作。") }
        }
    }

    func disable() {
        guard state != .off && state != .stopping else { return }
        guard let channel else {
            cleanup(); state = .off; return // Late authorization cannot connect or seize.
        }
        state = .stopping
        timer?.invalidate(); timer = nil
        let id = runID
        _ = channel.send("STOP")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.runID == id, self.state == .stopping else { return }
            self.fail("恢复操作未收到确认，后台将自动退出。请确认内置键盘恢复。")
        }
    }

    private func fail(_ message: String) {
        // Stop lease renewal immediately; keep re-enable disabled until the independent watchdog expires.
        cleanup(); state = .stopping; error = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            if self?.runID == nil { self?.state = .off }
        }
    }

    private func cleanup() {
        runID = nil; selection = nil
        timer?.invalidate(); timer = nil
        channel?.close(); channel = nil
        listener?.close(); listener = nil
        serviceConnection?.invalidate(); serviceConnection = nil
    }

    func stop() {
        _ = channel?.send("STOP")
        cleanup(); state = .off
        manager.stop()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }
}

#if UI_PREVIEW
extension KeyboardControlModel {
    static func preview() -> KeyboardControlModel {
        let model = KeyboardControlModel()
        model.devices = [
            KeyboardDevice(registryID: 1, product: "Apple Internal Keyboard / Trackpad", transport: "FIFO",
                           builtIn: true, primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6)],
                           ancestry: ["AppleHIDTransportHIDDevice"]),
            KeyboardDevice(registryID: 2, product: "外接蓝牙键盘", transport: "Bluetooth Low Energy",
                           builtIn: nil, primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6)], ancestry: ["IOHIDUserDevice"])
        ]
        return model
    }
}
#endif
