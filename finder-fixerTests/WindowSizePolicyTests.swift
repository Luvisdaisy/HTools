import XCTest
@testable import finder_fixer

final class WindowSizePolicyTests: XCTestCase {
    func testNegativeCoordinatesAndPrimaryHeightConversion() {
        let frame = CGRect(x: -1920, y: -100, width: 1920, height: 1080)
        XCTAssertEqual(WindowSizePolicy.axRect(from: frame, primaryHeight: 1440), CGRect(x: -1920, y: 460, width: 1920, height: 1080))
    }
    func testFitPreservesPreferenceAndKeepsFrameVisible() {
        let preference = WindowSize(width: 1800, height: 1200)
        let visible = CGRect(x: -1280, y: 30, width: 1280, height: 690)
        let actual = WindowSizePolicy.fit(preference, origin: CGPoint(x: -80, y: 600), into: visible)
        XCTAssertEqual(actual, visible)
        XCTAssertEqual(preference, WindowSize(width: 1800, height: 1200))
    }
    func testSmallWindowKeepsPositionWhenAlreadyVisible() {
        XCTAssertEqual(WindowSizePolicy.fit(.initial, origin: CGPoint(x: 80, y: 60), into: CGRect(x: 0, y: 25, width: 1920, height: 1000)), CGRect(x: 80, y: 60, width: 1000, height: 700))
    }
    func testSelectsLargestIntersectionAndNearestOffscreenDisplay() {
        let left = DisplayArea(frame: CGRect(x: -1280, y: 0, width: 1280, height: 800), visibleFrame: .zero)
        let right = DisplayArea(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visibleFrame: .zero)
        XCTAssertEqual(WindowSizePolicy.display(for: CGRect(x: -100, y: 40, width: 1000, height: 700), among: [left,right]), right)
        XCTAssertEqual(WindowSizePolicy.display(for: CGRect(x: -3000, y: 0, width: 100, height: 100), among: [left,right]), left)
    }
    func testInputValidationRejectsFractionsOverflowAndNonFiniteValues() {
        for bad in ["", "0", "-100", "99", "10001", "1e3", "100.5", "１２３", "nan", "99999999999999999999999999999999999"] {
            XCTAssertNil(WindowSize.parse(width: bad, height: "700"), bad)
        }
        XCTAssertEqual(WindowSize.parse(width: " 1000 ", height: "700"), .initial)
        XCTAssertFalse(WindowSize(width: .infinity, height: 700).isValid)
        XCTAssertFalse(WindowSize(width: 1000, height: .nan).isValid)
    }
}
