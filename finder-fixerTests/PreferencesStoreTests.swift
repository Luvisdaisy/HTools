import XCTest
@testable import finder_fixer

final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() { suite = "finder-fixer.tests.\(UUID())"; defaults = UserDefaults(suiteName: suite) }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testRoundtripPreservesFixedSizeAndToggle() {
        let store = PreferencesStore(defaults: defaults)
        var prefs = Preferences()
        prefs.fixedSize = WindowSize(width: 1100, height: 650)
        prefs.autoApplyEnabled = false
        store.save(prefs)
        XCTAssertEqual(store.load(), prefs)
    }
    func testCorruptedDataFallsBackWithoutCrashing() {
        defaults.set(Data("not-json".utf8), forKey: "windowPreferences.v1")
        XCTAssertEqual(PreferencesStore(defaults: defaults).load(), Preferences())
    }
    func testOldDualModeDataMigratesUsingFixedSizeOnly() {
        let old = #"{"mode":"remember","fixedSize":{"width":1200,"height":800},"rememberedSize":{"width":900,"height":640},"memoryInitialized":true,"autoApplyEnabled":false}"#
        defaults.set(Data(old.utf8), forKey: "windowPreferences.v1")
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load().fixedSize, WindowSize(width: 1200, height: 800))
        XCTAssertFalse(store.load().autoApplyEnabled)
        store.save(store.load())
        let saved = String(data: defaults.data(forKey: "windowPreferences.v1")!, encoding: .utf8)!
        XCTAssertFalse(saved.contains("remember"))
        XCTAssertFalse(saved.contains("mode"))
    }
    func testInvalidSaveDoesNotReplaceLastGoodSettings() {
        let store = PreferencesStore(defaults: defaults)
        var prefs = Preferences(); prefs.fixedSize = WindowSize(width: 1200, height: 800)
        store.save(prefs); prefs.fixedSize.width = .nan; store.save(prefs)
        XCTAssertEqual(store.load().fixedSize.width, 1200)
    }
    func testInvalidStoredSizeFallsBackAndPreservesToggle() {
        let bad = #"{"fixedSize":{"width":-1,"height":800},"autoApplyEnabled":false}"#
        defaults.set(Data(bad.utf8), forKey: "windowPreferences.v1")
        let loaded = PreferencesStore(defaults: defaults).load()
        XCTAssertEqual(loaded.fixedSize, .initial)
        XCTAssertFalse(loaded.autoApplyEnabled)
    }
    func testRevokedPermissionDoesNotSaveOrBlockHiddenDraft() {
        let store = PreferencesStore(defaults: defaults)
        let service = FinderWindowService()
        let model = SettingsModel(store: store, service: service)
        service.onStatus?(FinderServiceStatus(trusted: true))
        model.widthText = "invalid"
        XCTAssertFalse(model.prepareToClose())
        service.onStatus?(FinderServiceStatus(trusted: false))
        XCTAssertTrue(model.prepareToClose())
        XCTAssertEqual(model.widthText, "invalid")
        XCTAssertEqual(store.load().fixedSize, .initial)
        service.onStatus?(FinderServiceStatus(trusted: true))
        XCTAssertFalse(model.prepareToClose())
        model.widthText = "1200"
        XCTAssertTrue(model.prepareToClose())
        XCTAssertEqual(store.load().fixedSize.width, 1200)
    }

    func testHiddenValidDraftIsNotImplicitlySaved() {
        let store = PreferencesStore(defaults: defaults)
        let model = SettingsModel(store: store)
        model.widthText = "1200"
        XCTAssertTrue(model.prepareToClose())
        XCTAssertEqual(store.load().fixedSize, .initial)
        XCTAssertEqual(model.widthText, "1200")
    }
}
