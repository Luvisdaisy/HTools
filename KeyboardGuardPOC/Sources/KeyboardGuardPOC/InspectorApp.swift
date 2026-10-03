import AppKit
import KeyboardCore

final class InspectorApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let manager = HIDDeviceManager()
    private let evidenceDirectory: URL
    private var evidence: FileHandle?
    private var evidenceURL: URL?
    private var window: NSWindow!
    private let inventory = NSTextView()
    private let input = NSTextView()
    private let status = NSTextField(wrappingLabelWithString: "正在枚举键盘…")
    private let logPath = NSTextField(wrappingLabelWithString: "")
    private let externalMenu = NSPopUpButton()
    private let startButton = NSButton(title: "开始 30 秒测试", target: nil, action: nil)
    private let releaseButton = NSButton(title: "立即释放", target: nil, action: nil)
    private let baseline = NSButton(checkboxWithTitle: "已确认两把实体键盘均可输入，并已松开所有按键", target: nil, action: nil)
    private var observations: [NSButton] = []
    private var externals: [KeyboardDevice] = []
    private var process: Process?
    private var outputPipe: Pipe?
    private var pending = Data()
    private var runID = UUID().uuidString
    private var state: SessionState = .available
    private var seizeSucceeded = false
    private var releaseSucceeded = false
    private var workerFailed = false
    private var lastAPIError = ""
    private var quitting = false
    private var deadline: Date?
    private var displayTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    init(evidenceDirectory: String?) {
        self.evidenceDirectory = evidenceDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ??
            FileManager.default.temporaryDirectory.appendingPathComponent("KeyboardGuardPOC", isDirectory: true)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        do {
            try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
            let url = evidenceDirectory.appendingPathComponent("session-\(UUID().uuidString).jsonl")
            guard FileManager.default.createFile(atPath: url.path, contents: nil,
                                                 attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            evidence = try FileHandle(forWritingTo: url); evidenceURL = url
            logPath.stringValue = "证据：\(url.path)"
            record(EvidenceEvent(runID: runID, kind: "inspector_started",
                message: ProcessInfo.processInfo.operatingSystemVersionString))
        } catch { status.stringValue = "证据文件不可写：\(error.localizedDescription)" }
        manager.changed = { [weak self] kind, device in
            guard let self else { return }
            self.record(EvidenceEvent(runID: self.runID, kind: "inspector_\(kind)", device: device))
            self.refreshInventory()
        }
        manager.failed = { [weak self] code in
            guard let self else { return }
            self.record(EvidenceEvent(runID: self.runID, kind: "inspector_error", code: code))
            self.status.stringValue = "设备枚举出错：\(code)"; self.releaseNow()
        }
        let code = manager.start()
        record(EvidenceEvent(runID: runID, kind: "inspector_manager_open", code: code))
        status.stringValue = code == 0 ? "AVAILABLE · 先在下方输入框分别测试内置和外接键盘。" : "枚举失败：\(code)"
        refreshInventory()
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.releaseNow()
            })
        }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let deadline = self.deadline, self.state == .blocked else { return }
            self.status.stringValue = "BLOCKED · API 独占成功；约 \(max(0, Int(deadline.timeIntervalSinceNow))) 秒后释放。请测试物理输入。"
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "KeyboardGuard POC · Phase 1 + 2"
        window.delegate = self; window.minSize = NSSize(width: 800, height: 740); window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20)
        ])
        let title = NSTextField(labelWithString: "内置键盘隔离验证")
        title.font = .systemFont(ofSize: 23, weight: .semibold); stack.addArrangedSubview(title)
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "1. 核对设备并测试两把键盘  →  2. 开始限时独占  →  3. 分别测试内置、外接和触控板  →  4. 释放后测试内置恢复"))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        inventory.isEditable = false; inventory.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        inventory.isHorizontallyResizable = false; inventory.autoresizingMask = [.width]
        inventory.textContainer?.widthTracksTextView = true; scroll.documentView = inventory
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 210).isActive = true
        let chooser = NSStackView(views: [NSTextField(labelWithString: "本轮外接键盘："), externalMenu])
        externalMenu.target = self; externalMenu.action = #selector(selectionChanged)
        stack.addArrangedSubview(chooser)
        baseline.target = self; baseline.action = #selector(selectionChanged); stack.addArrangedSubview(baseline)
        startButton.target = self; startButton.action = #selector(startTest)
        releaseButton.target = self; releaseButton.action = #selector(releaseNow); releaseButton.isEnabled = false
        let permission = NSButton(title: "输入监控权限…", target: self, action: #selector(openPermissions))
        stack.addArrangedSubview(NSStackView(views: [startButton, releaseButton, permission]))
        status.font = .systemFont(ofSize: 13, weight: .semibold); stack.addArrangedSubview(status)
        let testScroll = NSScrollView(); testScroll.borderType = .bezelBorder; testScroll.hasVerticalScroller = true
        input.isRichText = false; input.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        input.autoresizingMask = [.width]; input.textContainer?.widthTracksTextView = true
        testScroll.documentView = input; stack.addArrangedSubview(testScroll)
        testScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        testScroll.heightAnchor.constraint(equalToConstant: 70).isActive = true
        stack.addArrangedSubview(NSButton(title: "清空输入框（内容不会写入证据）", target: self, action: #selector(clearInput)))
        for (i, title) in ["独占期间：内置普通键及修饰键不产生系统输入", "独占期间：外接实体键盘可以正常输入",
                           "独占期间：内置触控板移动、点击正常", "释放之后：内置实体键盘恢复输入"].enumerated() {
            let check = NSButton(checkboxWithTitle: title, target: self, action: #selector(observe(_:)))
            check.tag = i; check.isEnabled = false; observations.append(check); stack.addArrangedSubview(check)
        }
        logPath.font = .systemFont(ofSize: 10); logPath.isSelectable = true; stack.addArrangedSubview(logPath)
        let menu = NSMenu(); let item = NSMenuItem(); let submenu = NSMenu()
        submenu.addItem(NSMenuItem(title: "退出 POC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.submenu = submenu; menu.addItem(item)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(action), keyEquivalent: key))
        }
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
    }

    private func refreshInventory() {
        let all = manager.devices.values.sorted { $0.registryID < $1.registryID }
        inventory.string = all.map { d in
            let c = d.classification
            return "\(d.product)  [\(c.role.rawValue)]  score=\(String(format: "%.2f", c.confidence))\n" +
                "  registry=\(d.registryID)  transport=\(d.transport)  Built-In=\(d.builtIn.map(String.init) ?? "missing")" +
                "  VID=\(d.vendorID.map(String.init) ?? "missing") PID=\(d.productID.map(String.init) ?? "missing")\n" +
                "  usages=\(d.usages.map { "\($0.page):\($0.usage)" }.joined(separator: ","))\n" +
                "  \(c.reasons.joined(separator: "; "))\n"
        }.joined(separator: "\n")
        let selectedID = externalMenu.selectedItem?.representedObject as? UInt64
        externals = all.filter { $0.classification.role == .external }
        externalMenu.removeAllItems()
        for device in externals {
            externalMenu.addItem(withTitle: "\(device.product) · \(device.transport) · \(device.registryID)")
            externalMenu.lastItem?.representedObject = device.registryID
        }
        if let selectedID, let index = externals.firstIndex(where: { $0.registryID == selectedID }) {
            externalMenu.selectItem(at: index)
        } else { baseline.state = .off }
        selectionChanged()
    }

    @objc private func selectionChanged() {
        startButton.isEnabled = process == nil && evidence != nil && baseline.state == .on &&
            manager.devices.values.filter { $0.classification.role == .builtIn }.count == 1 &&
            externalMenu.selectedItem != nil
        baseline.isEnabled = process == nil; externalMenu.isEnabled = process == nil
    }

    @objc private func startTest() {
        guard process == nil, startButton.isEnabled,
              let target = manager.devices.values.first(where: { $0.classification.role == .builtIn }),
              let external = externalMenu.selectedItem?.representedObject as? UInt64 else { return }
        runID = UUID().uuidString; state = .blocking; seizeSucceeded = false; releaseSucceeded = false; workerFailed = false
        lastAPIError = ""
        observations.forEach { $0.state = .off; $0.isEnabled = false }
        record(EvidenceEvent(runID: runID, kind: "baseline_confirmed", source: "user_observation"))
        let child = Process(); child.executableURL = Bundle.main.executableURL
        child.arguments = ["--seize", String(target.registryID), "--external", String(external),
                           "--seconds", "30", "--run-id", runID]
        let pipe = Pipe(); child.standardOutput = pipe; child.standardError = FileHandle.nullDevice
        child.standardInput = FileHandle.nullDevice
        outputPipe = pipe; pending = Data()
        do {
            try child.run(); process = child; deadline = Date().addingTimeInterval(30)
            try? pipe.fileHandleForWriting.close()
            // One reader preserves JSONL ordering through EOF; never race a termination handler
            // against another pipe read or publish completion before the release result arrives.
            DispatchQueue.global().async { [weak self] in
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    DispatchQueue.main.async { self?.consume(data) }
                }
                child.waitUntilExit()
                try? pipe.fileHandleForReading.close()
                DispatchQueue.main.async { self?.workerEnded(child) }
            }
            releaseButton.isEnabled = true; selectionChanged(); input.string = ""
            window.makeFirstResponder(input)
            status.stringValue = "BLOCKING · 正在尝试独占内置键盘…"
            // Independent of the AppKit event loop; SIGKILL also works if worker is stopped/hung.
            DispatchQueue.global().asyncAfter(deadline: .now() + 35) {
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            }
        } catch {
            try? pipe.fileHandleForReading.close(); try? pipe.fileHandleForWriting.close()
            status.stringValue = "启动失败：\(error.localizedDescription)"; state = .error
            record(EvidenceEvent(runID: runID, kind: "launch_error", message: error.localizedDescription))
        }
    }

    private func workerEnded(_ ended: Process) {
        process = nil; outputPipe = nil; deadline = nil; releaseButton.isEnabled = false
        observations.prefix(3).forEach { $0.isEnabled = false }
        observations[3].isEnabled = seizeSucceeded && releaseSucceeded && !workerFailed && ended.terminationStatus == 0
        record(EvidenceEvent(runID: runID, kind: "supervisor_worker_ended",
            message: "status=\(ended.terminationStatus); reason=\(ended.terminationReason.rawValue)"))
        baseline.state = .off; selectionChanged()
        if ended.terminationStatus == 0 && releaseSucceeded {
            status.stringValue = "AVAILABLE · release API 成功；请用内置键盘输入并确认恢复。"
        } else {
            status.stringValue = "ERROR · \(lastAPIError) · worker 已结束（\(ended.terminationStatus)）。请核对输入监控权限与证据。"
        }
        if quitting { NSApp.reply(toApplicationShouldTerminate: true) }
    }

    private func consume(_ data: Data) {
        pending.append(data)
        while let end = pending.firstIndex(of: 0x0a) {
            let line = pending.prefix(upTo: end); pending.removeSubrange(...end)
            guard let event = try? JSONDecoder().decode(EvidenceEvent.self, from: line) else { continue }
            record(event)
            if let state = event.state { self.state = state }
            if event.kind == "seize_result", event.code == 0 {
                seizeSucceeded = true; observations.prefix(3).forEach { $0.isEnabled = true }
            }
            if event.kind == "release_result" {
                releaseSucceeded = event.code == 0
                observations.prefix(3).forEach { $0.isEnabled = false }
            }
            if event.state == .error { workerFailed = true }
            if event.kind == "administrator_required" {
                lastAPIError = "键盘独占需要管理员 worker；输入监控权限不足以完成独占。请使用 run-keyboard-poc.sh"
            }
            if let code = event.code, code != 0 {
                lastAPIError = "\(event.codeHex ?? String(code)) \(event.message ?? event.kind)"
            }
        }
    }

    @objc private func releaseNow() {
        guard let process, process.isRunning else { return }
        record(EvidenceEvent(runID: runID, kind: "manual_release_requested"))
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    @objc private func observe(_ sender: NSButton) {
        record(EvidenceEvent(runID: runID, kind: ["internal_blocked", "external_works", "trackpad_works", "internal_restored"][sender.tag],
            state: state, message: sender.state == .on ? "confirmed" : "withdrawn", source: "user_observation"))
        if observations.allSatisfy({ $0.state == .on }) && seizeSucceeded && releaseSucceeded && !workerFailed {
            status.stringValue = "本轮 API 链路成功，四项物理行为已由用户确认。其他机型与热插拔场景需单独验证。"
        }
    }

    @objc private func clearInput() { input.string = ""; window.makeFirstResponder(input) }
    @objc private func openPermissions() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    private func record(_ event: EvidenceEvent) {
        do { try evidence?.write(contentsOf: event.jsonLine) }
        catch {
            evidence = nil; startButton.isEnabled = false
            status.stringValue = "证据写入失败，测试已停止。"
            if let process, process.isRunning { process.terminate() }
        }
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let process, process.isRunning else { return .terminateNow }
        quitting = true; releaseNow()
        return .terminateLater
    }
    func applicationWillTerminate(_ notification: Notification) {
        // Exiting the supervisor must not leave its child holding a HID device.
        if let process, process.isRunning { kill(process.processIdentifier, SIGKILL) }
        manager.stop(); displayTimer?.invalidate()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        try? evidence?.close()
    }
}
