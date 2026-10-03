import AppKit
import IOKit.hidsystem
import KeyboardCore

final class Worker {
    let manager = HIDDeviceManager()
    lazy var session = SeizeSession(controller: manager)
    let runID: String
    var signals: [DispatchSourceSignal] = []
    var timeout: DispatchSourceTimer?
    var parentWatch: DispatchSourceTimer?
    var observations: [NSObjectProtocol] = []
    var ending = false
    var exitStatus: Int32 = 0

    init(runID: String) { self.runID = runID }

    func run(target: UInt64?, external: UInt64?, seconds: Int, watch: Bool = false) -> Never {
        signal(SIGPIPE, SIG_IGN)
        emit(EvidenceEvent(runID: runID, kind: "environment", message:
            "\(ProcessInfo.processInfo.operatingSystemVersionString); pid=\(getpid()); euid=\(geteuid()); duration=\(seconds)s"))
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let accessName = access == kIOHIDAccessTypeGranted ? "granted" :
            (access == kIOHIDAccessTypeDenied ? "denied" : "unknown")
        emit(EvidenceEvent(runID: runID, kind: "input_monitoring_access", message: accessName))
        session.event = { [weak self] kind, state, code in
            guard let self else { return }
            let error = code.flatMap { $0 == 0 ? nil : String(cString: mach_error_string($0)) }
            emit(EvidenceEvent(runID: self.runID, kind: kind, state: state, code: code, message: error))
            if kind == "seize_result", code == kIOReturnNotPrivileged {
                emit(EvidenceEvent(runID: self.runID, kind: "administrator_required", state: state,
                    message: "Keyboard seize requires a privileged IOKit client; Input Monitoring alone is insufficient. Use the bounded administrator POC script; no persistent helper is installed."))
            }
        }
        manager.changed = { [weak self] kind, device in
            guard let self else { return }
            emit(EvidenceEvent(runID: self.runID, kind: kind, device: device))
            if kind == "removed", device.registryID == self.session.target || device.registryID == self.session.external {
                self.finish("device_removed")
            }
        }
        manager.failed = { [weak self] code in
            guard let self else { return }
            emit(EvidenceEvent(runID: self.runID, kind: "discovery_error", code: code))
            self.exitStatus = 2; self.finish("discovery_error")
        }
        let opened = manager.start()
        emit(EvidenceEvent(runID: runID, kind: "manager_open", code: opened))
        guard opened == 0 else { exit(2) }
        guard target != nil || watch else { manager.stop(); exit(0) }

        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.finish("signal_\(sig)") }
            source.resume(); signals.append(source)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification,
                     NSWorkspace.screensDidSleepNotification] {
            observations.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.finish("sleep_or_session_inactive")
            })
        }
        let originalParent = getppid()
        // A separate queue can terminate the worker even if the HID run loop/API hangs.
        let watchdogQueue = DispatchQueue(label: "keyboard-poc.watchdog")
        let parentWatch = DispatchSource.makeTimerSource(queue: watchdogQueue)
        parentWatch.schedule(deadline: .now() + 0.25, repeating: 0.25)
        parentWatch.setEventHandler { [weak self] in
            if getppid() != originalParent {
                DispatchQueue.main.async { [weak self] in self?.finish("parent_exit") }
                watchdogQueue.asyncAfter(deadline: .now() + 1) { kill(getpid(), SIGKILL) }
            }
        }
        parentWatch.resume(); self.parentWatch = parentWatch

        if target != nil {
            watchdogQueue.asyncAfter(deadline: .now() + .seconds(seconds + 3)) { kill(getpid(), SIGKILL) }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + .seconds(seconds))
            timer.setEventHandler { [weak self] in self?.finish("timeout") }
            timer.resume(); timeout = timer
            // Let pending discovery/removal notifications run before evaluating current inventory.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, let target, let external else { return }
                guard self.session.start(devices: Array(self.manager.devices.values), target: target, external: external) else {
                    self.exitStatus = 2; self.finish("seize_refused_or_failed")
                }
            }
        }
        RunLoop.main.run()
        finish("runloop_ended")
    }

    func finish(_ reason: String) -> Never {
        if ending { exit(3) }
        ending = true
        session.release(reason: reason)
        if session.state == .error { exitStatus = 2 }
        // End the process on close failure; do not emit a false AVAILABLE state.
        if session.target == nil { manager.stop() }
        emit(EvidenceEvent(runID: runID, kind: "worker_exit", state: session.state,
                           message: "reason=\(reason); exit=\(exitStatus); physical recovery requires observation"))
        exit(exitStatus)
    }
}
