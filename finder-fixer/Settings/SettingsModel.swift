import AppKit
import Combine

final class SettingsModel: ObservableObject {
    @Published private(set) var preferences: Preferences
    @Published var widthText: String
    @Published var heightText: String
    @Published private(set) var status = FinderServiceStatus()
    @Published var inputError: String?
    let service: FinderWindowService
    private let store: PreferencesStore
    private var revision: UInt64 = 0

    init(store: PreferencesStore = PreferencesStore(), service: FinderWindowService = FinderWindowService()) {
        self.store = store; self.service = service
        let preferences = store.load()
        self.preferences = preferences
        widthText = String(Int(preferences.fixedSize.width.rounded()))
        heightText = String(Int(preferences.fixedSize.height.rounded()))
        service.onStatus = { [weak self] status in self?.status = status }

    }

    var dirty: Bool {
        widthText != String(Int(preferences.fixedSize.width.rounded())) || heightText != String(Int(preferences.fixedSize.height.rounded()))
    }
    var validDraft: Bool { WindowSize.parse(width: widthText, height: heightText) != nil }

    func start() { sendConfiguration(); updateDisplays(); service.start() }
    func updateDisplays() {
        guard let primary = NSScreen.screens.first else { return }
        service.setDisplays(NSScreen.screens.map {
            DisplayArea(frame: WindowSizePolicy.axRect(from: $0.frame, primaryHeight: primary.frame.height),
                        visibleFrame: WindowSizePolicy.axRect(from: $0.visibleFrame, primaryHeight: primary.frame.height))
        })
    }

    @discardableResult func saveDraft() -> Bool {
        guard dirty else { inputError = nil; return true }
        guard let size = WindowSize.parse(width: widthText, height: heightText) else {
            inputError = "宽度和高度请输入 100–10000 的整数。"; return false
        }
        preferences.fixedSize = size
        resetDraft(); sendConfiguration()
        return true
    }

    func resetDraft() {
        widthText = String(Int(preferences.fixedSize.width.rounded()))
        heightText = String(Int(preferences.fixedSize.height.rounded()))
        inputError = nil
    }

    func setAutoApply(_ enabled: Bool) {
        preferences.autoApplyEnabled = enabled
        sendConfiguration()
    }

    // Hidden drafts must never prevent closing the permission gate.
    func prepareToClose() -> Bool {
        !status.trusted || saveDraft()
    }

    func openPermissionSettings() { AccessibilityPermission.openSettings() }

    private func sendConfiguration() {
        revision &+= 1
        store.save(preferences)
        service.configure(preferences, revision: revision)
    }

}
