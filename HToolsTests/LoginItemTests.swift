import XCTest
import ServiceManagement
@testable import HTools

final class LoginItemTests: XCTestCase {
    private final class Service: LoginItemServicing {
        var status: SMAppService.Status = .notRegistered
        var registeredStatus: SMAppService.Status = .enabled
        var failure: Error?
        var registrations = 0
        var removals = 0
        var settingsOpened = 0
        func register() throws {
            registrations += 1
            if let failure { throw failure }
            status = registeredStatus
        }
        func unregister() throws {
            removals += 1
            if let failure { throw failure }
            status = .notRegistered
        }
        func openSettings() { settingsOpened += 1 }
    }

    func testInitialReadAndRefreshNeverRegister() {
        let service = Service()
        let model = LoginItemModel(service: service)
        XCTAssertFalse(model.isEnabled)
        service.status = .enabled
        model.refresh()
        XCTAssertTrue(model.isEnabled)
        service.status = .notRegistered
        model.refresh()
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.removals, 0)
    }

    func testEnableDisableUsesSystemStatusAndAvoidsDuplicateOperations() {
        let service = Service()
        let model = LoginItemModel(service: service)
        model.setEnabled(true); model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertEqual(service.registrations, 1)
        XCTAssertNil(model.error)
        model.setEnabled(false); model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertEqual(service.removals, 1)
    }

    func testApprovalCanOpenSettingsAndBeCancelled() {
        let service = Service(); service.registeredStatus = .requiresApproval
        let model = LoginItemModel(service: service)
        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertTrue(model.needsApproval)
        model.openSettings()
        XCTAssertEqual(service.settingsOpened, 1)
        model.setEnabled(false)
        XCTAssertFalse(model.isEnabled)
        XCTAssertFalse(model.needsApproval)
        XCTAssertEqual(service.removals, 1)
    }

    func testRegisterFailureKeepsRealStatusAndCanRetry() {
        let service = Service(); service.failure = NSError(domain: "test", code: 1)
        let model = LoginItemModel(service: service)
        model.setEnabled(true)
        XCTAssertFalse(model.isEnabled)
        XCTAssertNotNil(model.error)
        service.failure = nil
        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertNil(model.error)
    }

    func testUnregisterFailureDoesNotPretendDisabled() {
        let service = Service(); service.status = .enabled
        service.failure = NSError(domain: "test", code: 2)
        let model = LoginItemModel(service: service)
        model.setEnabled(false)
        XCTAssertTrue(model.isEnabled)
        XCTAssertNotNil(model.error)
    }

    func testChangeReconcilesExternalStatusBeforeActing() {
        let service = Service()
        let model = LoginItemModel(service: service)
        service.status = .enabled
        model.setEnabled(false)
        XCTAssertEqual(service.removals, 1)
        XCTAssertFalse(model.isEnabled)
    }

    func testMissingApplicationIsNotReportedAsEnabled() {
        let service = Service(); service.registeredStatus = .notFound
        let model = LoginItemModel(service: service)
        model.setEnabled(true)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(model.status, .notFound)
        XCTAssertFalse(model.detail.isEmpty)
    }
}
