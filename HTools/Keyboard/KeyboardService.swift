import AppKit
import Security
import SystemConfiguration

@objc protocol KeyboardServiceProtocol {
    func status(reply: @escaping (String, Bool) -> Void)
    func startSession(path: String, internalID: UInt64, externalID: UInt64, reply: @escaping (String?) -> Void)
    func stopSession(reply: @escaping () -> Void)
}

/// Both directions pin the exact signed executable, including ad-hoc builds.
/// Updating the executable requires reinstalling the helper from Permissions.
enum KeyboardServiceIdentity {
    static let name = "local.HTools.keyboard"
    static let bundlePath = "/Library/PrivilegedHelperTools/HToolsKeyboard.app"
    static let executable = bundlePath + "/Contents/MacOS/HTools"
    static let plist = "/Library/LaunchDaemons/" + name + ".plist"
    static let version = "2"

    static func requirement() throws -> String {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let hash = (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else {
            throw POSIXError(.EAUTH)
        }
        return "cdhash H\"" + hash.map { String(format: "%02x", $0) }.joined() + "\""
    }

    static func connect() throws -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: name, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: KeyboardServiceProtocol.self)
        connection.setCodeSigningRequirement(try requirement())
        return connection
    }

    static func validSocketPath(_ path: String, uid: uid_t) -> Bool {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent().path
        guard url.lastPathComponent == "control",
              directory.hasPrefix("/tmp/HTools.") || directory.hasPrefix("/private/tmp/HTools."),
              url.deletingLastPathComponent().deletingLastPathComponent().path == "/tmp" ||
                url.deletingLastPathComponent().deletingLastPathComponent().path == "/private/tmp" else { return false }
        var folder = stat(); var socket = stat()
        return lstat(directory, &folder) == 0 && folder.st_uid == uid &&
            folder.st_mode & S_IFMT == S_IFDIR && folder.st_mode & 0o777 == 0o700 &&
            lstat(path, &socket) == 0 && socket.st_uid == uid &&
            socket.st_mode & S_IFMT == S_IFSOCK && socket.st_mode & 0o777 == 0o600
    }
}

final class KeyboardService: NSObject, NSXPCListenerDelegate {
    private var worker: Process?
    private var owner: UUID?

    // launchctl adopts the login user's bootstrap and audit session, but keeps
    // root credentials. Both the readiness probe and HID worker use this path.
    static func sessionProcess(uid: uid_t, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["asuser", String(uid), KeyboardServiceIdentity.executable] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }

    fileprivate func checkAccess(uid: uid_t, reply: @escaping (String, Bool) -> Void) {
        var consoleUID: uid_t = 0
        _ = SCDynamicStoreCopyConsoleUser(nil, &consoleUID, nil)
        guard uid != 0, consoleUID == uid else { reply(KeyboardServiceIdentity.version, false); return }
        let process = Self.sessionProcess(uid: uid, arguments: ["--keyboard-access-check"])
        process.terminationHandler = { ended in
            reply(KeyboardServiceIdentity.version, ended.terminationReason == .exit && ended.terminationStatus == 0)
        }
        do {
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if process.isRunning { process.terminate() }
            }
        } catch { reply(KeyboardServiceIdentity.version, false) }
    }

    static func run() -> Never {
        guard geteuid() == 0 else { exit(2) }
        do {
            let service = KeyboardService()
            let listener = NSXPCListener(machServiceName: KeyboardServiceIdentity.name)
            listener.setConnectionCodeSigningRequirement(try KeyboardServiceIdentity.requirement())
            listener.delegate = service
            listener.resume()
            withExtendedLifetime((listener, service)) { RunLoop.main.run() }
        } catch { exit(2) }
        exit(0)
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier != 0 else { return false }
        let id = UUID()
        let client = KeyboardServiceClient(service: self, id: id, pid: connection.processIdentifier,
                                           uid: connection.effectiveUserIdentifier)
        connection.exportedInterface = NSXPCInterface(with: KeyboardServiceProtocol.self)
        connection.exportedObject = client
        connection.invalidationHandler = { [weak self] in DispatchQueue.main.async { self?.stop(owner: id) } }
        connection.interruptionHandler = { [weak self] in DispatchQueue.main.async { self?.stop(owner: id) } }
        connection.resume()
        return true
    }

    fileprivate func start(owner: UUID, pid: pid_t, uid: uid_t, path: String,
                           internalID: UInt64, externalID: UInt64) -> String? {
        var consoleUID: uid_t = 0
        _ = SCDynamicStoreCopyConsoleUser(nil, &consoleUID, nil)
        guard consoleUID == uid, pid > 1, internalID != externalID,
              KeyboardServiceIdentity.validSocketPath(path, uid: uid) else { return "请求无效或当前用户会话已失活。" }
        guard worker == nil else { return "已有键盘会话正在运行或恢复，请稍后重试。" }
        // Never execute a path or command supplied by a client.
        let process = Self.sessionProcess(uid: uid, arguments: [
            "--keyboard-worker", path, String(pid), String(uid), String(internalID), String(externalID)
        ])
        process.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async {
                guard self?.worker === ended else { return }
                self?.worker = nil; self?.owner = nil
            }
        }
        do { try process.run(); worker = process; self.owner = owner; return nil }
        catch { return "无法启动键盘服务，请在权限设置中重新安装。" }
    }

    fileprivate func stop(owner: UUID) {
        guard self.owner == owner, let process = worker else { return }
        if process.isRunning { process.terminate() }
        // Keep the slot occupied until the process actually exits.
    }
}

private final class KeyboardServiceClient: NSObject, KeyboardServiceProtocol {
    weak var service: KeyboardService?
    let id: UUID
    let pid: pid_t
    let uid: uid_t
    init(service: KeyboardService, id: UUID, pid: pid_t, uid: uid_t) {
        self.service = service; self.id = id; self.pid = pid; self.uid = uid
    }
    func status(reply: @escaping (String, Bool) -> Void) {
        DispatchQueue.main.async { [self] in
            guard let service else { reply(KeyboardServiceIdentity.version, false); return }
            service.checkAccess(uid: uid, reply: reply)
        }
    }
    func startSession(path: String, internalID: UInt64, externalID: UInt64, reply: @escaping (String?) -> Void) {
        DispatchQueue.main.async { [self] in
            guard let service else { reply("键盘服务不可用。"); return }
            reply(service.start(owner: id, pid: pid, uid: uid, path: path, internalID: internalID, externalID: externalID))
        }
    }
    func stopSession(reply: @escaping () -> Void) {
        DispatchQueue.main.async { [self] in service?.stop(owner: id); reply() }
    }
}
