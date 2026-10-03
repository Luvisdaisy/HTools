import Foundation

public protocol PhysicalKeyboardControlling: AnyObject {
    func seize(_ registryID: UInt64) -> Int32
    func release(_ registryID: UInt64) -> Int32
}

public enum SessionState: String, Codable { case available, blocking, blocked, releasing, error }

/// All callers must use the same serial queue/run loop as the HID backend.
public final class SeizeSession {
    public private(set) var state: SessionState = .available
    public private(set) var target: UInt64?
    public private(set) var external: UInt64?
    public private(set) var lastError: String?
    public var event: (String, SessionState, Int32?) -> Void = { _, _, _ in }
    private let controller: PhysicalKeyboardControlling

    public init(controller: PhysicalKeyboardControlling) { self.controller = controller }

    @discardableResult
    public func start(devices: [KeyboardDevice], target: UInt64, external: UInt64) -> Bool {
        guard state == .available else { return false }
        let internals = devices.filter { $0.classification.role == .builtIn }
        guard Set(devices.map(\.registryID)).count == devices.count,
              internals.count == 1, internals[0].registryID == target,
              devices.filter({ $0.builtIn == true && $0.classification.role != .virtual }).count == 1,
              devices.contains(where: { $0.registryID == external && $0.classification.role == .external }),
              target != external else {
            lastError = "refused: ambiguous internal device or selected external absent"
            event(lastError!, state, nil)
            return false
        }
        self.target = target; self.external = external
        state = .blocking; event("seize_requested", state, nil)
        let code = controller.seize(target)
        if code == 0 {
            state = .blocked; event("seize_result", state, code)
            return true
        }
        state = .error; lastError = "seize failed"
        // No successful ownership was obtained; do not pretend a close was needed/succeeded.
        self.target = nil; self.external = nil
        event("seize_result", state, code)
        return false
    }

    public func removed(_ registryID: UInt64) {
        guard registryID == target || registryID == external else { return }
        release(reason: registryID == external ? "external_removed" : "target_removed")
    }

    public func release(reason: String) {
        guard let target, state == .blocked || state == .error else { return }
        state = .releasing; event(reason, state, nil)
        let code = controller.release(target)
        if code == 0 {
            self.target = nil; external = nil; state = .available
        } else {
            state = .error; lastError = "release failed; worker must terminate to relinquish ownership"
        }
        event("release_result", state, code)
    }
}
