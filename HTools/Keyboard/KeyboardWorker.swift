import AppKit
import IOKit
import IOKit.hidsystem
import OSLog

/// Transient administrator mode. Never creates windows or starts the Finder service.
final class KeyboardWorker {
    private let manager = HIDDeviceManager()
    private let log = Logger(subsystem: "local.HTools", category: "keyboard-worker")

    static func checkAccess() -> Never {
        guard geteuid() == 0 else { exit(2) }
        // Checking access never requests consent, opens devices or seizes input.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { _exit(3) }
        exit(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted ? 0 : 77)
    }
    private lazy var session = SeizeSession(controller: manager)
    private let lease = KeyboardLease()
    private var channel: KeyboardChannel?
    private var timer: DispatchSourceTimer?
    private var watchdog: DispatchSourceTimer?
    private var signals: [DispatchSourceSignal] = []
    private var observers: [NSObjectProtocol] = []
    private var ending = false
    private var started = false

    static func run(arguments: [String]) -> Never {
        guard arguments.count == 5, geteuid() == 0,
              let parent = Int32(arguments[1]), parent > 1,
              let uid = UInt32(arguments[2]), uid != 0,
              let target = UInt64(arguments[3]), let external = UInt64(arguments[4]), target != external else { exit(2) }
        let worker = KeyboardWorker()
        worker.run(path: arguments[0], parent: parent, uid: uid, target: target, external: external)
    }

    private func run(path: String, parent: pid_t, uid: uid_t, target: UInt64, external: UInt64) -> Never {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { exit(2) }
        let connected = (try? KeyboardChannel.address(path) { Darwin.connect(fd, $0, $1) }) == 0
        guard connected, KeyboardChannel.peer(fd, uid: uid, pid: parent) else { Darwin.close(fd); exit(2) }
        let channel = KeyboardChannel(fd); self.channel = channel
        channel.disconnected = { [weak self] in self?.finish() }
        channel.received = { [weak self] command in
            guard let self else { return }
            switch command {
            case "PING":
                self.lease.renew()
                if !self.started {
                    self.started = true
                    self.begin(target: target, external: external)
                }
                _ = self.channel?.send("PONG")
            case "STOP": self.finish()
            default: self.finish(error: "控制连接无效，请重新开启。")
            }
        }
        channel.start()
        let queue = DispatchQueue(label: "HTools.keyboard-watchdog")
        let watchdog = DispatchSource.makeTimerSource(queue: queue)
        watchdog.schedule(deadline: .now() + 0.25, repeating: 0.25)
        watchdog.setEventHandler { [lease] in
            if lease.expired(after: 5) { _exit(3) }
        }
        watchdog.resume(); self.watchdog = watchdog
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            if self?.lease.expired(after: 3) == true { self?.finish() }
        }
        timer.resume(); self.timer = timer
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.finish() }
            source.resume(); signals.append(source)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.finish()
            })
        }
        RunLoop.main.run()
        finish()
    }

    private func begin(target: UInt64, external: UInt64) {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        log.notice("Input access=\(access.rawValue), euid=\(geteuid())")
        guard access == kIOHIDAccessTypeGranted else {
            finish(error: "后台键盘进程尚未获得输入监控权限，请返回权限设置检查后台权限状态。")
        }
        manager.changed = { [weak self] kind, device in
            guard let self else { return }
            if kind == "removed", device.registryID == target || device.registryID == external { self.finish() }
        }
        manager.failed = { [weak self] _ in self?.finish(error: "无法检测键盘，请关闭后重新开启。") }
        guard manager.start() == 0 else { finish(error: "无法访问键盘。请在系统设置中允许 HTools 监控输入。") }
        session.event = { [weak self] kind, _, code in
            if let code { self?.log.notice("HID \(kind, privacy: .public) result=\(code)") }
            if kind == "seize_result", let code, code != 0 {
                self?.finish(error: String(format: "无法禁用内置键盘（0x%08x）。请检查输入监控权限或其他键盘工具。", UInt32(bitPattern: code)))
            }
        }
        guard session.start(devices: Array(manager.devices.values), target: target, external: external) else {
            finish(error: "键盘连接已变化或无法安全识别内置键盘，请检查连接后重试。")
        }
        _ = channel?.send("BLOCKED")
    }

    private func finish(error: String? = nil) -> Never {
        guard !ending else { _exit(3) }
        ending = true
        // Bound close() itself, even when called while the GUI continues sending heartbeats.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { _exit(3) }
        session.release(reason: "integrated_stop")
        if session.state == .error && session.target != nil {
            _ = channel?.send("ERROR:恢复操作失败，后台进程将退出；请确认内置键盘恢复。")
            exit(2)
        }
        if let error { _ = channel?.send("ERROR:" + error) }
        else { _ = channel?.send("RELEASED") }
        exit(error == nil ? 0 : 2)
    }
}
