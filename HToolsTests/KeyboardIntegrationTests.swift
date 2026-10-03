import XCTest
import Darwin
@testable import HTools

final class KeyboardIntegrationTests: XCTestCase {
    private func builtIn(_ id: UInt64 = 1) -> KeyboardDevice {
        KeyboardDevice(registryID: id, product: "Internal", transport: "FIFO", builtIn: true,
                       primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6)], ancestry: ["AppleHIDTransportHIDDevice"])
    }
    private func external(_ id: UInt64 = 2) -> KeyboardDevice {
        KeyboardDevice(registryID: id, product: "Node75", transport: "Bluetooth Low Energy", builtIn: nil,
                       primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6)], ancestry: ["IOHIDUserDevice"])
    }

    func testSelectionRequiresTrustedInternalAndExternal() {
        XCTAssertEqual(KeyboardSelection.resolve([external(), builtIn()]), KeyboardSelection(internalID: 1, externalID: 2))
        XCTAssertNil(KeyboardSelection.resolve([builtIn()]))
        XCTAssertNil(KeyboardSelection.resolve([external()]))
        XCTAssertNil(KeyboardSelection.resolve([builtIn(), builtIn(3), external()]))
        XCTAssertNil(KeyboardSelection.resolve([builtIn(), external(), external()]))
    }

    func testUnknownBuiltInAndCompositeCannotBeSeized() {
        var composite = builtIn(4); composite.usages.append(HIDUsage(1, 2))
        XCTAssertNil(KeyboardSelection.resolve([composite, external()]))
        XCTAssertNil(KeyboardSelection.resolve([builtIn(), composite, external()]))
        var unknown = builtIn(); unknown.builtIn = nil
        XCTAssertNil(KeyboardSelection.resolve([unknown, external()]))
    }

    func testMultipleExternalsUseStableSelectionAndIgnoreVirtual() {
        var virtual = external(3); virtual.virtualProperty = true
        XCTAssertEqual(KeyboardSelection.resolve([external(8), builtIn(), external(5), virtual])?.externalID, 5)
        XCTAssertNil(KeyboardSelection.resolve([builtIn(), virtual]))
    }

    func testLeaseExpiresAndRenewalMovesDeadline() {
        let lease = KeyboardLease(now: 100)
        XCTAssertFalse(lease.expired(after: 3, now: 102.99))
        XCTAssertTrue(lease.expired(after: 3, now: 103))
        lease.renew(now: 102)
        XCTAssertFalse(lease.expired(after: 3, now: 104))
        XCTAssertTrue(lease.expired(after: 5, now: 107))
    }

    func testShellQuotingPreservesMetacharactersLiterally() throws {
        let literal = "a 'quote' \"double\" $HOME $(id) `id` \\ slash\nnext"
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "/usr/bin/printf %s " + KeyboardAuthorization.shellQuote(literal)]
        process.standardOutput = output
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), literal)
    }

    func testAuthorizationScriptCompilesWithoutExecuting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("authorize.applescript")
        try KeyboardAuthorization.script(executable: "/tmp/a 'quoted' \"app\"", arguments: ["--keyboard-worker", "a\\b"]).write(to: source, atomically: true, encoding: .utf8)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
        process.arguments = ["-o", directory.appendingPathComponent("authorize.scpt").path, source.path]
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testLocalSocketPermissionsAndCleanup() throws {
        let listener = try KeyboardListener()
        let directory = (listener.path as NSString).deletingLastPathComponent
        let mode = try FileManager.default.attributesOfItem(atPath: listener.path)[.posixPermissions] as? NSNumber
        let parentMode = try FileManager.default.attributesOfItem(atPath: directory)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600)
        XCTAssertEqual(parentMode?.intValue, 0o700)
        listener.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory))
    }

    func testChannelFramesMultipleMessagesAndDeliversDisconnect() throws {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds), 0)
        let sender = KeyboardChannel(fds[0]), receiver = KeyboardChannel(fds[1])
        let messages = expectation(description: "Framed messages"); messages.expectedFulfillmentCount = 2
        let disconnected = expectation(description: "Socket EOF")
        var lines: [String] = []
        receiver.received = { line in lines.append(line); messages.fulfill() }
        receiver.disconnected = { disconnected.fulfill() }
        receiver.start()
        XCTAssertTrue(sender.send("PING")); XCTAssertTrue(sender.send("STOP"))
        wait(for: [messages], timeout: 2)
        XCTAssertEqual(lines, ["PING", "STOP"])
        sender.close()
        wait(for: [disconnected], timeout: 2)
        receiver.close()
    }

    func testOversizedProtocolFrameDisconnects() {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds), 0)
        let sender = KeyboardChannel(fds[0]), receiver = KeyboardChannel(fds[1])
        let ended = expectation(description: "Oversized frame rejected")
        receiver.disconnected = { ended.fulfill() }
        receiver.received = { _ in XCTFail("Oversized command accepted") }
        receiver.start()
        _ = sender.send(String(repeating: "X", count: 5000))
        wait(for: [ended], timeout: 2)
        sender.close(); receiver.close()
    }

    func testWorkerRefusesUnprivilegedLaunchBeforeHIDAccess() throws {
        guard geteuid() != 0 else { throw XCTSkip("Requires ordinary user") }
        let process = Process(); process.executableURL = Bundle.main.executableURL
        process.arguments = ["--keyboard-worker", "/tmp/nonexistent", String(getpid()), String(getuid()), "1", "2"]
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 2)
    }

    func testListenerRejectsUnprivilegedPeerAndVerifiesServerIdentity() throws {
        guard geteuid() != 0 else { throw XCTSkip("Requires ordinary user") }
        let listener = try KeyboardListener()
        listener.accepted = { _ in XCTFail("Unprivileged worker accepted") }
        listener.start()
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertEqual(try KeyboardChannel.address(listener.path) { Darwin.connect(fd, $0, $1) }, 0)
        XCTAssertTrue(KeyboardChannel.peer(fd, uid: getuid(), pid: getpid()))
        XCTAssertFalse(KeyboardChannel.peer(fd, uid: getuid(), pid: getpid() + 1))
        XCTAssertFalse(KeyboardChannel.peer(fd, uid: 0))
        let client = KeyboardChannel(fd)
        let ended = expectation(description: "Unprivileged peer rejected")
        client.disconnected = { ended.fulfill() }; client.start()
        wait(for: [ended], timeout: 2)
        client.close(); listener.close()
    }
}
