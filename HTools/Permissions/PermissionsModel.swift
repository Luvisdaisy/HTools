import AppKit
import ApplicationServices
import Combine
import IOKit.hidsystem

struct PermissionStatus: Equatable {
    var accessibility = false
    var inputMonitoring = false
    var keyboardService = false
    var workerInputMonitoring = false
    var keyboardReady: Bool { inputMonitoring && keyboardService && workerInputMonitoring }
    var complete: Bool { accessibility && keyboardReady }
    var completedSteps: Int { [accessibility, inputMonitoring, keyboardService && workerInputMonitoring].filter { $0 }.count }
}

final class PermissionsModel: ObservableObject {
    @Published private(set) var status = PermissionStatus()
    @Published private(set) var busy = false
    @Published private(set) var serviceInstalled = FileManager.default.fileExists(atPath: KeyboardServiceIdentity.plist)
    @Published private(set) var checking = false
    @Published var error: String?
    @Published private(set) var setupCompleted: Bool
    var beforeServiceChange: () -> Void = {}
    private let defaults: UserDefaults
    private var timer: Timer?
    private var probe: NSXPCConnection?
    private var probeID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupCompleted = defaults.bool(forKey: "permissionsSetupCompleted.v1")
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func refresh() {
        serviceInstalled = FileManager.default.fileExists(atPath: KeyboardServiceIdentity.plist)
        status.accessibility = AXIsProcessTrusted()
        status.inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        guard !busy, probe == nil else { return }
        checking = true
        do {
            let connection = try KeyboardServiceIdentity.connect()
            let id = UUID(); probeID = id; probe = connection
            let finish: (Bool, Bool) -> Void = { [weak self] ready, inputReady in
                DispatchQueue.main.async {
                    guard let self, self.probeID == id else { return }
                    self.probeID = nil
                    var status = self.status
                    status.keyboardService = ready
                    status.workerInputMonitoring = ready && inputReady
                    self.status = status
                    self.checking = false
                    self.probe?.invalidate(); self.probe = nil
                }
            }
            connection.invalidationHandler = { finish(false, false) }
            connection.interruptionHandler = { finish(false, false) }
            connection.resume()
            let remote = connection.remoteObjectProxyWithErrorHandler { _ in finish(false, false) } as? KeyboardServiceProtocol
            remote?.status { finish($0 == KeyboardServiceIdentity.version, $1) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if self?.probeID == id { finish(false, false) }
            }
        } catch { status.keyboardService = false; status.workerInputMonitoring = false; checking = false }
    }

    func requestAccessibility() { AccessibilityPermission.openSettings() }
    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func configureService(install: Bool) {
        guard !busy else { return }
        beforeServiceChange()
        probeID = nil; probe?.invalidate(); probe = nil
        checking = false
        busy = true; error = nil; status.keyboardService = false; status.workerInputMonitoring = false
        do {
            try KeyboardServiceInstaller.run(install: install) { [weak self] error in
                guard let self else { return }
                self.busy = false; self.error = error; self.refresh()
            }
        } catch { busy = false; self.error = error.localizedDescription }
    }

    func completeSetup() {
        guard status.complete else { return }
        defaults.set(true, forKey: "permissionsSetupCompleted.v1")
        setupCompleted = true
    }

    func stop() {
        timer?.invalidate(); timer = nil
        probeID = nil; probe?.invalidate(); probe = nil
    }
}

#if UI_PREVIEW
extension PermissionsModel {
    static func preview(defaults: UserDefaults, ready: Bool) -> PermissionsModel {
        let model = PermissionsModel(defaults: defaults)
        model.status = PermissionStatus(accessibility: ready, inputMonitoring: ready,
                                        keyboardService: ready, workerInputMonitoring: ready)
        model.serviceInstalled = ready
        model.setupCompleted = ready
        return model
    }
}
#endif
