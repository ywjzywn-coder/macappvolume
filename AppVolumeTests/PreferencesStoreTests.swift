import XCTest
@testable import AppVolume

final class PreferencesStoreTests: XCTestCase {
    func testDefaultStateAndPersistence() throws {
        let suiteName = "local.appvolume.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.state(for: "com.example.app").volume, 1)
        XCTAssertFalse(store.state(for: "com.example.app").isMuted)

        store.setVolume(0.35, for: "com.example.app")
        store.setMuted(true, for: "com.example.app")

        let reloaded = PreferencesStore(defaults: defaults)
        let state = reloaded.state(for: "com.example.app")
        XCTAssertEqual(state.volume, 0.35, accuracy: 0.0001)
        XCTAssertTrue(state.isMuted)
    }

    func testNeedsTapControl() {
        XCTAssertFalse(AppVolumeState.default.needsTapControl)
        XCTAssertTrue(AppVolumeState(volume: 0.5, isMuted: false).needsTapControl)
        XCTAssertTrue(AppVolumeState(volume: 0, isMuted: false).needsTapControl)
        XCTAssertTrue(AppVolumeState(volume: 1, isMuted: true).needsTapControl)
        XCTAssertFalse(AppVolumeState(volume: 1, isMuted: false).needsTapControl)
    }
}
