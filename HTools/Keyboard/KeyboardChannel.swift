import Foundation
import Darwin

/// Local-only IPC. No keyboard reports or text input cross this channel.
final class KeyboardChannel {
    private(set) var descriptor: Int32
    private var source: DispatchSourceRead?
    private var buffer = Data()
    var received: (String) -> Void = { _ in }
    var disconnected: () -> Void = {}

    init(_ descriptor: Int32) {
        self.descriptor = descriptor
        var enabled: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
    }

    static func address<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
        var address = sockaddr_un()
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw POSIXError(.ENAMETOOLONG) }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            bytes.withUnsafeBytes { destination.copyBytes(from: $0) }
        }
        return try withUnsafePointer(to: &address) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { try body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
    }

    static func peer(_ descriptor: Int32, uid: uid_t, pid: pid_t? = nil) -> Bool {
        var actualUID: uid_t = 0; var group: gid_t = 0
        guard getpeereid(descriptor, &actualUID, &group) == 0, actualUID == uid else { return false }
        guard let pid else { return true }
        var actualPID: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(descriptor, SOL_LOCAL, LOCAL_PEERPID, &actualPID, &length) == 0 && actualPID == pid
    }

    func start() {
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
        source.setEventHandler { [weak self] in self?.readAvailable() }
        // Close only after the dispatch source relinquishes its descriptor (avoid fd reuse races).
        let fd = descriptor
        source.setCancelHandler { Darwin.close(fd) }
        self.source = source; source.resume()
    }

    @discardableResult func send(_ line: String) -> Bool {
        guard descriptor >= 0 else { return false }
        let data = Data((line + "\n").utf8)
        let written = data.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress, $0.count, MSG_DONTWAIT) }
        guard written == data.count else { close(); disconnected(); return false }
        return true
    }

    func close() {
        guard descriptor >= 0 else { return }
        // shutdown immediately delivers EOF to the peer even before the cancel handler runs.
        shutdown(descriptor, SHUT_RDWR)
        if let source { source.cancel(); self.source = nil } else { Darwin.close(descriptor) }
        descriptor = -1
    }

    private func readAvailable() {
        var bytes = [UInt8](repeating: 0, count: 1024)
        let count = recv(descriptor, &bytes, bytes.count, 0)
        if count < 0 && (errno == EAGAIN || errno == EINTR) { return }
        guard count > 0 else { close(); disconnected(); return }
        buffer.append(contentsOf: bytes.prefix(count))
        guard buffer.count <= 4096 else { close(); disconnected(); return }
        while let end = buffer.firstIndex(of: 10) {
            let line = String(decoding: buffer[..<end], as: UTF8.self)
            buffer.removeSubrange(...end)
            received(line)
            if descriptor < 0 { return }
        }
    }

    deinit { close() }
}

final class KeyboardListener {
    let path: String
    private let directory: String
    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?
    var accepted: (KeyboardChannel) -> Void = { _ in }

    init() throws {
        var template = Array("/tmp/HTools.XXXXXX".utf8CString)
        guard let created = mkdtemp(&template) else { throw POSIXError(.EIO) }
        directory = String(cString: created)
        path = directory + "/control"
        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { rmdir(directory); throw POSIXError(.EIO) }
        do {
            let result = try KeyboardChannel.address(path) { Darwin.bind(descriptor, $0, $1) }
            guard result == 0, chmod(path, 0o600) == 0, listen(descriptor, 1) == 0 else { throw POSIXError(.EIO) }
            _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
        } catch {
            Darwin.close(descriptor); unlink(path); rmdir(directory); throw error
        }
    }

    func start() {
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let fd = accept(self.descriptor, nil, nil)
            guard fd >= 0 else { return }
            guard KeyboardChannel.peer(fd, uid: 0) else { Darwin.close(fd); return }
            self.accepted(KeyboardChannel(fd))
        }
        let fd = descriptor
        source.setCancelHandler { Darwin.close(fd) }
        self.source = source; source.resume()
    }

    func close() {
        guard descriptor >= 0 else { return }
        if let source { source.cancel(); self.source = nil } else { Darwin.close(descriptor) }
        descriptor = -1
        unlink(path); rmdir(directory)
    }
    deinit { close() }
}
