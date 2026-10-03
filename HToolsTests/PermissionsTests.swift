import XCTest
import Security
@testable import HTools

final class PermissionsTests: XCTestCase {
    func testSetupRequiresEveryPermission() {
        for mask in 0..<16 {
            let status = PermissionStatus(accessibility: mask & 1 != 0, inputMonitoring: mask & 2 != 0,
                                          keyboardService: mask & 4 != 0, workerInputMonitoring: mask & 8 != 0)
            XCTAssertEqual(status.complete, mask == 15)
        }
    }

    func testSetupCannotBeMarkedCompleteWithoutLivePermissions() throws {
        let name = "HTools.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = PermissionsModel(defaults: defaults)
        model.completeSetup()
        XCTAssertFalse(model.setupCompleted)
        XCTAssertFalse(defaults.bool(forKey: "permissionsSetupCompleted.v1"))
    }

    func testMigrationPreservesExistingPreferencesAndDoesNotMigratePermissionClaims() throws {
        let name = "HTools.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var old = Preferences(); old.fixedSize = WindowSize(width: 1110, height: 720)
        let data = try JSONEncoder().encode(old)
        PreferencesStore.migrateLegacyPreferences(defaults: defaults, legacy: ["windowPreferences.v1": data, "hasLaunched": true])
        XCTAssertEqual(PreferencesStore(defaults: defaults).load().fixedSize, old.fixedSize)
        XCTAssertFalse(defaults.bool(forKey: "hasLaunched"))
        XCTAssertFalse(defaults.bool(forKey: "permissionsSetupCompleted.v1"))
        var newer = old; newer.fixedSize = WindowSize(width: 1200, height: 800)
        PreferencesStore(defaults: defaults).save(newer)
        PreferencesStore.migrateLegacyPreferences(defaults: defaults, legacy: ["windowPreferences.v1": data])
        XCTAssertEqual(PreferencesStore(defaults: defaults).load().fixedSize, newer.fixedSize)
    }

    func testMigrationRejectsMalformedPreferences() throws {
        let name = "HTools.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        PreferencesStore.migrateLegacyPreferences(defaults: defaults, legacy: ["windowPreferences.v1": Data("bad".utf8)])
        XCTAssertNil(defaults.data(forKey: "windowPreferences.v1"))
    }

    func testServiceSocketValidationRejectsWrongOwnerModesAndSymlinks() throws {
        let listener = try KeyboardListener()
        defer { listener.close() }
        XCTAssertTrue(KeyboardServiceIdentity.validSocketPath(listener.path, uid: getuid()))
        XCTAssertFalse(KeyboardServiceIdentity.validSocketPath(listener.path, uid: getuid() + 1))
        XCTAssertFalse(KeyboardServiceIdentity.validSocketPath("/tmp/arbitrary/control", uid: getuid()))
        XCTAssertFalse(KeyboardServiceIdentity.validSocketPath(listener.path + "/../control", uid: getuid()))
        XCTAssertEqual(chmod(listener.path, 0o666), 0)
        XCTAssertFalse(KeyboardServiceIdentity.validSocketPath(listener.path, uid: getuid()))
        XCTAssertEqual(chmod(listener.path, 0o600), 0)
        let alias = "/tmp/HTools.\(UUID())"
        try FileManager.default.createSymbolicLink(atPath: alias, withDestinationPath: (listener.path as NSString).deletingLastPathComponent)
        defer { try? FileManager.default.removeItem(atPath: alias) }
        XCTAssertFalse(KeyboardServiceIdentity.validSocketPath(alias + "/control", uid: getuid()))
    }

    func testCodeSigningRequirementMatchesOnlyCurrentCode() throws {
        let text = try KeyboardServiceIdentity.requirement()
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString(text as CFString, [], &requirement), errSecSuccess)
        var current: SecCode?
        XCTAssertEqual(SecCodeCopySelf([], &current), errSecSuccess)
        XCTAssertEqual(SecCodeCheckValidity(try XCTUnwrap(current), [], requirement), errSecSuccess)
        var other: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(URL(fileURLWithPath: "/usr/bin/true") as CFURL, [], &other), errSecSuccess)
        XCTAssertNotEqual(SecStaticCodeCheckValidity(try XCTUnwrap(other), [], requirement), errSecSuccess)
    }

    func testInstallerShellParsesWithoutExecution() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for script in [KeyboardServiceInstaller.installScript(bundle: "/a 'quoted' \"path\" $(id)\nHTools", digest: String(repeating: "a", count: 64)), KeyboardServiceInstaller.uninstallScript] {
            let url = directory.appendingPathComponent("install.sh")
            try script.write(to: url, atomically: true, encoding: .utf8)
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-n", url.path]
            try process.run(); process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0)
            let appleScript = directory.appendingPathComponent("install.applescript")
            try KeyboardServiceInstaller.authorizationScript(command: script, install: true)
                .write(to: appleScript, atomically: true, encoding: .utf8)
            let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
            compiler.arguments = ["-o", directory.appendingPathComponent("install.scpt").path, appleScript.path]
            try compiler.run(); compiler.waitUntilExit()
            XCTAssertEqual(compiler.terminationStatus, 0)
        }
    }

    func testDaemonReachabilityDoesNotImplyKeyboardReady() {
        let status = PermissionStatus(accessibility: true, inputMonitoring: true, keyboardService: true,
                                      workerInputMonitoring: false)
        XCTAssertFalse(status.keyboardReady)
        XCTAssertFalse(status.complete)
    }

    func testWorkerAndProbeUseUserSessionWithoutShellInterpretation() {
        let path = "/tmp/HTools.'$(id)/control"
        let process = KeyboardService.sessionProcess(uid: 501, arguments: ["--keyboard-worker", path, "42", "501", "1", "2"])
        XCTAssertEqual(process.executableURL?.path, "/bin/launchctl")
        XCTAssertEqual(process.arguments, ["asuser", "501", KeyboardServiceIdentity.executable, "--keyboard-worker", path, "42", "501", "1", "2"])
        let probe = KeyboardService.sessionProcess(uid: 502, arguments: ["--keyboard-access-check"])
        XCTAssertEqual(probe.arguments, ["asuser", "502", KeyboardServiceIdentity.executable, "--keyboard-access-check"])
    }

    func testAccessProbeRefusesUnprivilegedLaunch() throws {
        guard geteuid() != 0 else { throw XCTSkip("Requires ordinary user") }
        let process = Process(); process.executableURL = Bundle.main.executableURL
        process.arguments = ["--keyboard-access-check"]
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 2)
    }

    func testServiceRefusesUnprivilegedLaunch() throws {
        guard geteuid() != 0 else { throw XCTSkip("Requires ordinary user") }
        let process = Process(); process.executableURL = Bundle.main.executableURL
        process.arguments = ["--keyboard-service"]
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 2)
    }
}
