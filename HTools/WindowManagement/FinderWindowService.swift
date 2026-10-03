import AppKit
import ApplicationServices
import os

struct FinderServiceStatus: Equatable {
    var trusted = false
    var finderRunning = false
    var availableWindows = 0
    var message = "需要辅助功能权限"
}

/// All AX calls and mutable window state live on queue. The main RunLoop only
/// delivers observer callbacks; they immediately enqueue work and return.
final class FinderWindowService {
    private final class Window {
        let id = UUID()
        let element: AXUIElement
        var pendingApply: DispatchWorkItem?
        init(_ element: AXUIElement) { self.element = element }
    }
    private let queue = DispatchQueue(label: "local.HTools.accessibility", qos: .userInitiated)
    private let log = Logger(subsystem: "local.HTools", category: "windows")
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var pid: pid_t?
    private var windows: [Window] = []
    private var preferences = Preferences()
    private var configurationRevision: UInt64 = 0
    private var generation: UInt64 = 0
    private var displays: [DisplayArea] = []
    private var timer: DispatchSourceTimer?
    private var stopped = true
    private var observationHealthy = true
    private var lastStatus = FinderServiceStatus()
    var onStatus: ((FinderServiceStatus) -> Void)?


    func start() {
        queue.async {
            guard self.stopped else { return }
            self.stopped = false
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 2)
            timer.setEventHandler { [weak service = self] in service?.refreshConnection() }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.timer?.cancel(); self.timer = nil
            self.unbind()
        }
    }

    func configure(_ preferences: Preferences, revision: UInt64) {
        queue.async {
            self.preferences = preferences
            self.configurationRevision = revision
            for window in self.windows {
                window.pendingApply?.cancel(); window.pendingApply = nil
            }
        }
    }

    func setDisplays(_ displays: [DisplayArea]) {
        queue.async {
            if self.displays != displays {
                for window in self.windows { window.pendingApply?.cancel() }
            }
            self.displays = displays
        }
    }

    func refresh() {
        queue.async {
            self.refreshConnection()
            if self.application != nil { self.reconcile() }
        }
    }

    private func refreshConnection() {
        guard !stopped else { return }
        guard AXIsProcessTrusted() else { unbind(); publishStatus(); return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        guard let newPID = running?.processIdentifier else { unbind(); publishStatus(); return }
        if newPID != pid {
            unbind()
            pid = newPID
            let app = AXUIElementCreateApplication(newPID)
            AXUIElementSetMessagingTimeout(app, 0.5)
            application = app
            var created: AXObserver?
            let result = AXObserverCreate(newPID, { _, element, notification, context in
                guard let context else { return }
                let service = Unmanaged<FinderWindowService>.fromOpaque(context).takeUnretainedValue()
                service.queue.async { service.handle(element, notification as String) }
            }, &created)
            guard result == .success, let created else {
                log.error("observer creation failed: \(result.rawValue)")
                unbind(); publishStatus(error: "无法监听访达，将自动重试。")
                return
            }
            observer = created
            let context = Unmanaged.passUnretained(self).toOpaque()
            let creation = AXObserverAddNotification(created, app, kAXWindowCreatedNotification as CFString, context)
            observationHealthy = creation == .success || creation == .notificationAlreadyRegistered
            for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
                AXObserverAddNotification(created, app, name as CFString, context)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            reconcile() // Existing windows are a baseline, never auto-applied.
            log.notice("bound Finder, observed windows=\(self.windows.count)")
        }
        publishStatus()
    }

    private func unbind() {
        generation &+= 1
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil; application = nil; pid = nil
        for window in windows { window.pendingApply?.cancel() }
        windows.removeAll()
        observationHealthy = true
    }

    private func reconcile() {
        guard !stopped, let application,
              let elements = read(application, kAXWindowsAttribute) as? [AXUIElement] else { publishStatus(); return }
        for window in windows where !elements.contains(where: { CFEqual($0, window.element) }) { remove(window) }
        for element in elements where standard(element) { _ = track(element) }
        publishStatus()
    }

    @discardableResult private func track(_ element: AXUIElement) -> Window {
        if let existing = windows.first(where: { CFEqual($0.element, element) }) { return existing }
        let window = Window(element)
        windows.append(window)
        if let observer {
            for name in [kAXUIElementDestroyedNotification,
                         kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
                let result = AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
                if name == kAXUIElementDestroyedNotification && result != .success && result != .notificationAlreadyRegistered { observationHealthy = false }
            }
        }
        return window
    }

    private func remove(_ window: Window) {
        window.pendingApply?.cancel()
        if let observer {
            for name in [kAXUIElementDestroyedNotification,
                         kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
                AXObserverRemoveNotification(observer, window.element, name as CFString)
            }
        }
        windows.removeAll { $0.id == window.id }
    }

    private func handle(_ element: AXUIElement, _ notification: String) {
        guard !stopped, AXIsProcessTrusted(), let pid else { return }
        var eventPID: pid_t = 0
        // Destroyed elements may no longer report a PID; membership still makes
        // their cleanup safe. Other stale process callbacks are discarded.
        let known = windows.first { CFEqual($0.element, element) }
        if notification == kAXUIElementDestroyedNotification {
            if let known { remove(known); publishStatus() }; return
        }
        guard AXUIElementGetPid(element, &eventPID) == .success, eventPID == pid else { return }
        if notification == kAXWindowCreatedNotification {
            if known == nil { discoverNew(element, attempt: 0, generation: generation, revision: configurationRevision) }
            return
        }
        if notification == kAXFocusedWindowChangedNotification || notification == kAXMainWindowChangedNotification {
            // Do not reconcile immediately: a focused event can precede a
            // creation event. Delaying preserves new-window classification.
            let token = generation
            queue.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, self.generation == token else { return }; self.reconcile()
            }
            return
        }
        guard let window = known else { return }
        if notification == kAXWindowMiniaturizedNotification || notification == kAXWindowDeminiaturizedNotification {
            window.pendingApply?.cancel()
        }
        publishStatus()
    }

    private func discoverNew(_ element: AXUIElement, attempt: Int, generation token: UInt64, revision: UInt64) {
        guard generation == token, configurationRevision == revision, !stopped else { return }
        guard standard(element), let initialFrame = frame(element), initialFrame.width > 0 else {
            guard attempt < 3 else { return }
            queue.asyncAfter(deadline: .now() + 0.15 * Double(attempt + 1)) { [weak self] in
                self?.discoverNew(element, attempt: attempt + 1, generation: token, revision: revision)
            }
            return
        }
        guard !windows.contains(where: { CFEqual($0.element, element) }) else { return }
        let window = track(element)
        if preferences.autoApplyEnabled && observationHealthy {
            let work = DispatchWorkItem { [weak self, weak window] in
                guard let self, let window, self.generation == token, self.configurationRevision == revision,
                      self.preferences.autoApplyEnabled, self.windows.contains(where: { $0 === window }),
                      !CGEventSource.buttonState(.combinedSessionState, button: .left) else { return }
                window.pendingApply = nil
                if self.applySize(to: window) == nil { self.publishStatus(error: "新窗口未能调整。") }
            }
            window.pendingApply = work
            queue.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
        publishStatus()
    }

    /// nil = failed; bool indicates Finder/screen constrained the preference.
    private func applySize(to window: Window) -> Bool? {
        guard !stopped, AXIsProcessTrusted(), eligible(window), let original = frame(window.element),
              let display = WindowSizePolicy.display(for: original, among: displays) else { return nil }
        let target = WindowSizePolicy.fit(preferences.fixedSize, origin: original.origin, into: display.visibleFrame)
        var size = target.size
        let sizeResult = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
        guard sizeResult == .success, let actual = frame(window.element) else {
            log.error("size write failed: \(sizeResult.rawValue)")
            return nil
        }
        // Finder may enforce a larger minimum than requested; reposition using
        // the returned size, never persist this constraint as a preference.
        let fitted = WindowSizePolicy.fit(WindowSize(actual.size), origin: actual.origin, into: display.visibleFrame)
        if abs(actual.minX - fitted.minX) > 1 || abs(actual.minY - fitted.minY) > 1 {
            var position = fitted.origin
            let result = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &position)!)
            guard result == .success else { return nil }
        }
        log.notice("applied window size \(actual.width)x\(actual.height)")
        return !preferences.fixedSize.matches(WindowSize(actual.size))
    }

    private func standard(_ element: AXUIElement) -> Bool {
        read(element, kAXRoleAttribute) as? String == kAXWindowRole &&
        read(element, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
    }

    private func eligible(_ window: Window) -> Bool {
        guard standard(window.element), read(window.element, kAXMinimizedAttribute) as? Bool == false,
              read(window.element, "AXFullScreen") as? Bool == false else { return false }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(window.element, kAXSizeAttribute as CFString, &settable) == .success && settable.boolValue
    }

    private func frame(_ element: AXUIElement) -> CGRect? {
        guard let sizeValue = read(element, kAXSizeAttribute), CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              let positionValue = read(element, kAXPositionAttribute), CFGetTypeID(positionValue) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero, position = CGPoint.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size), AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              size.width.isFinite, size.height.isFinite, position.x.isFinite, position.y.isFinite else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func read(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private func publishStatus(error: String? = nil) {
        var status = FinderServiceStatus()
        status.trusted = AXIsProcessTrusted()
        status.finderRunning = pid != nil
        status.availableWindows = status.trusted ? windows.filter { eligible($0) }.count : 0
        if !status.trusted { status.message = "需要辅助功能权限" }
        else if !status.finderRunning { status.message = "访达未运行，启动后将恢复。" }
        else if !observationHealthy { status.message = "访达窗口通知不可用，自动应用已暂停。" }
        else if let error { status.message = error }
        else if status.availableWindows == 0 { status.message = "没有可用的访达窗口" }
        else { status.message = "监听中" }
        guard status != lastStatus else { return }
        lastStatus = status
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }
}
