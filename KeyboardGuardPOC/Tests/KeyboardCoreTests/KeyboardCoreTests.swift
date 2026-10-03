import XCTest
@testable import KeyboardCore

final class KeyboardCoreTests: XCTestCase {
    func internalDevice(_ id: UInt64 = 1) -> KeyboardDevice {
        KeyboardDevice(registryID: id, product: "Name must not matter", transport: "FIFO", builtIn: true,
            primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6), HIDUsage(12, 1)],
            ancestry: ["AppleHIDTransportHIDDevice"])
    }
    func externalDevice(_ id: UInt64 = 2) -> KeyboardDevice {
        KeyboardDevice(registryID: id, product: "Node75", transport: "Bluetooth Low Energy", builtIn: nil,
            primary: HIDUsage(1, 6), usages: [HIDUsage(1, 6), HIDUsage(1, 2)], ancestry: ["IOHIDUserDevice"])
    }

    func testAppleSiliconInternalWithoutVendorIsRecognizedByTopology() {
        let d = internalDevice()
        XCTAssertEqual(d.classification.role, .builtIn)
        XCTAssertGreaterThanOrEqual(d.classification.confidence, 0.85)
    }
    func testNameAndAppleVendorDoNotProveInternal() {
        var d = externalDevice(); d.product = "Apple Internal Keyboard / Trackpad"; d.vendorID = 0x05ac
        XCTAssertEqual(d.classification.role, .external)
    }
    func testBluetoothIOHIDUserDeviceIsNotAutomaticallyVirtual() {
        XCTAssertEqual(externalDevice().classification.role, .external)
    }
    func testCompositePointingAndDigitizerInterfacesAreNeverSeized() {
        for usage in [HIDUsage(1, 1), HIDUsage(1, 2), HIDUsage(13, 5)] {
            var d = internalDevice(); d.usages.append(usage)
            XCTAssertEqual(d.classification.role, .ignored)
        }
    }
    func testMissingOrContradictoryBuiltInIsRejected() {
        for flag in [nil, false] as [Bool?] {
            var d = internalDevice(); d.builtIn = flag
            XCTAssertEqual(d.classification.role, .ignored)
        }
        var d = internalDevice(); d.transport = "Bluetooth"
        XCTAssertEqual(d.classification.role, .ignored)
    }
    func testUnknownTopologyAndMissingCollectionsRejected() {
        var d = internalDevice(); d.transport = "Unknown"; d.ancestry = []
        XCTAssertEqual(d.classification.role, .ignored)
        d = internalDevice(); d.usages = []
        XCTAssertEqual(d.classification.role, .ignored)
        d = externalDevice(); d.transport = "USB"
        XCTAssertEqual(d.classification.role, .ignored)
        d.ancestry = ["IOUSBHostHIDDevice", "IOUSBHostInterface"]
        XCTAssertEqual(d.classification.role, .external)
    }
    func testExplicitVirtualEvidenceOverridesKeyboardMetadata() {
        var d = internalDevice(); d.virtualProperty = true
        XCTAssertEqual(d.classification.role, .virtual)
        d = externalDevice(); d.ancestry.append("KarabinerVirtualHIDDevice")
        XCTAssertEqual(d.classification.role, .virtual)
    }
    func testNonKeyboardAndZeroIdentityRejected() {
        var d = internalDevice(); d.usages = [HIDUsage(1, 2)]
        XCTAssertEqual(d.classification.role, .ignored)
        XCTAssertEqual(internalDevice(0).classification.role, .ignored)
    }

    final class Controller: PhysicalKeyboardControlling {
        var opened: [UInt64] = []; var closed: [UInt64] = []
        var openCode: Int32 = 0; var closeCode: Int32 = 0
        func seize(_ id: UInt64) -> Int32 { opened.append(id); return openCode }
        func release(_ id: UInt64) -> Int32 { closed.append(id); return closeCode }
    }
    func testOnlyInternalSeizedAndSuccessfulTransitions() {
        let backend = Controller(); let session = SeizeSession(controller: backend)
        var states: [SessionState] = []
        session.event = { _, state, _ in states.append(state) }
        XCTAssertTrue(session.start(devices: [internalDevice(), externalDevice()], target: 1, external: 2))
        session.release(reason: "manual")
        session.release(reason: "duplicate")
        XCTAssertEqual(states, [.blocking, .blocked, .releasing, .available])
        XCTAssertEqual(backend.opened, [1]); XCTAssertEqual(backend.closed, [1])
    }
    func testAmbiguousMissingExternalDuplicateAndReversedTargetsRefused() {
        let inventories = [[internalDevice()], [internalDevice(), internalDevice(3), externalDevice()],
                           [internalDevice(), internalDevice(), externalDevice()]]
        for devices in inventories {
            let backend = Controller(); let session = SeizeSession(controller: backend)
            XCTAssertFalse(session.start(devices: devices, target: 1, external: 2))
            XCTAssertTrue(backend.opened.isEmpty)
        }
        let backend = Controller(); let session = SeizeSession(controller: backend)
        XCTAssertFalse(session.start(devices: [internalDevice(), externalDevice()], target: 2, external: 1))
        XCTAssertTrue(backend.opened.isEmpty)
    }
    func testSeizeFailureNeverBecomesBlockedAndPreservesOriginalCode() {
        let backend = Controller(); backend.openCode = -42
        let session = SeizeSession(controller: backend); var codes: [Int32] = []
        session.event = { _, _, code in if let code { codes.append(code) } }
        XCTAssertFalse(session.start(devices: [internalDevice(), externalDevice()], target: 1, external: 2))
        session.release(reason: "cleanup")
        XCTAssertEqual(session.state, .error); XCTAssertEqual(codes, [-42]); XCTAssertTrue(backend.closed.isEmpty)
    }
    func testReleaseFailureRetainsOwnershipAndNeverReportsAvailable() {
        let backend = Controller(); backend.closeCode = -99
        let session = SeizeSession(controller: backend)
        XCTAssertTrue(session.start(devices: [internalDevice(), externalDevice()], target: 1, external: 2))
        session.release(reason: "timeout")
        XCTAssertEqual(session.state, .error); XCTAssertEqual(session.target, 1)
        backend.closeCode = 0; session.release(reason: "retry")
        XCTAssertEqual(session.state, .available); XCTAssertNil(session.target)
    }
    func testTargetOrSelectedExternalRemovalReleasesButUnrelatedDoesNot() {
        for removedID: UInt64 in [1, 2] {
            let backend = Controller(); let session = SeizeSession(controller: backend)
            XCTAssertTrue(session.start(devices: [internalDevice(), externalDevice()], target: 1, external: 2))
            session.removed(999); XCTAssertTrue(backend.closed.isEmpty)
            session.removed(removedID); XCTAssertEqual(backend.closed, [1]); XCTAssertEqual(session.state, .available)
            session.removed(removedID); XCTAssertEqual(backend.closed, [1])
        }
    }
    func testCannotSeizeTwiceDuringSession() {
        let backend = Controller(); let session = SeizeSession(controller: backend)
        let devices = [internalDevice(), externalDevice()]
        XCTAssertTrue(session.start(devices: devices, target: 1, external: 2))
        XCTAssertFalse(session.start(devices: devices, target: 1, external: 2))
        XCTAssertEqual(backend.opened, [1])
    }
    func testUnclassifiedSecondBuiltInKeyboardAlsoBlocksSeize() {
        var uncertain = internalDevice(3); uncertain.transport = "Unknown"; uncertain.ancestry = []
        let backend = Controller(); let session = SeizeSession(controller: backend)
        XCTAssertFalse(session.start(devices: [internalDevice(), uncertain, externalDevice()], target: 1, external: 2))
        XCTAssertTrue(backend.opened.isEmpty)
    }
}
