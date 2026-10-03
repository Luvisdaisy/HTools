import Foundation

struct KeyboardSelection: Equatable {
    let internalID: UInt64
    let externalID: UInt64

    static func resolve(_ devices: [KeyboardDevice]) -> KeyboardSelection? {
        let internalDevices = devices.filter { $0.classification.role == .builtIn }
        let externals = devices.filter { $0.classification.role == .external }.sorted { $0.registryID < $1.registryID }
        guard Set(devices.map(\.registryID)).count == devices.count,
              internalDevices.count == 1,
              devices.filter({ $0.builtIn == true && $0.classification.role != .virtual }).count == 1,
              let external = externals.first else { return nil }
        return KeyboardSelection(internalID: internalDevices[0].registryID, externalID: external.registryID)
    }
}

/// Monotonic, thread-safe lease; a separate watchdog also reads it if the main run loop hangs.
final class KeyboardLease {
    private let lock = NSLock()
    private var lastBeat: TimeInterval
    init(now: TimeInterval = ProcessInfo.processInfo.systemUptime) { lastBeat = now }
    func renew(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.lock(); defer { lock.unlock() }; lastBeat = now
    }
    func expired(after seconds: TimeInterval, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        lock.lock(); defer { lock.unlock() }; return now - lastBeat >= seconds
    }
}

enum KeyboardAuthorization {
    static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    static func script(executable: String, arguments: [String]) -> String {
        let command = "exec " + ([executable] + arguments).map(shellQuote).joined(separator: " ")
        let literal = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(literal)\" with administrator privileges with prompt \"HTools 需要暂时禁用内置键盘。\""
    }
}
