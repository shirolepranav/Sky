// SharedDefaultsTests.swift
// Phase 3 automated tests (Roadmap Phase 3 → Automated Tests). Round-trips a
// FamilyActivitySelection through SharedDefaults on an isolated suite and checks
// the empty / invalid-data edge cases.

import XCTest
import FamilyControls
@testable import Sky

final class SharedDefaultsTests: XCTestCase {
    private let suiteName = "SharedDefaultsTests"
    private var defaults: UserDefaults!
    private var store: SharedDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedDefaults(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    /// An (empty) selection survives a write/read round-trip via Codable archiving.
    /// Opaque tokens can't be fabricated in tests, so we round-trip the container
    /// itself and assert it decodes cleanly.
    func testEncodeDecodeFamilyActivitySelection() {
        let selection = FamilyActivitySelection()
        store.selection = selection

        XCTAssertNotNil(store.familyActivitySelection, "selection should persist as Data")
        XCTAssertNotNil(store.selection, "stored Data should decode back to a selection")
        XCTAssertFalse(store.selectionNeedsRedo)
    }

    /// No stored selection: accessors are nil/false and nothing crashes.
    func testEmptySelectionDoesNotCrash() {
        XCTAssertNil(store.selection)
        XCTAssertFalse(store.hasSelection)
        XCTAssertFalse(store.selectionNeedsRedo)
    }

    /// Corrupt stored Data (e.g. tokens invalidated by an iOS update) surfaces as
    /// `selectionNeedsRedo`, not a crash.
    func testInvalidSelectionDataFlagsNeedsRedo() {
        store.familyActivitySelection = Data("not a selection".utf8)

        XCTAssertNil(store.selection)
        XCTAssertFalse(store.hasSelection)
        XCTAssertTrue(store.selectionNeedsRedo)
    }

    /// `isCurrentlyBlocked` correctly round-trips writes through the App Group
    /// store — this is the flag that the DeviceActivityMonitor extension sets
    /// when a threshold is reached (Phase 5).
    func testIsCurrentlyBlockedWriteAndRead() {
        XCTAssertFalse(store.isCurrentlyBlocked, "default should be false")
        store.isCurrentlyBlocked = true
        XCTAssertTrue(store.isCurrentlyBlocked)
        store.isCurrentlyBlocked = false
        XCTAssertFalse(store.isCurrentlyBlocked)
    }

    /// Defaults match Tech Spec §6.1.
    func testDefaultsMatchSpec() {
        XCTAssertEqual(store.limitMode, "combined")
        XCTAssertEqual(store.combinedLimitSeconds, 7200)
        XCTAssertTrue(store.limitsEnabled)
        XCTAssertFalse(store.isCurrentlyBlocked)
        XCTAssertFalse(store.didVerifyToday)
        XCTAssertEqual(store.todayResetToken, "")
        XCTAssertEqual(store.todayStateDay, "")
        XCTAssertNil(store.shieldedAppTokens)
    }

    /// The stamp that lets a late midnight reset tell yesterday's flags from
    /// today's. Empty until something writes today-state.
    func testTodayStateDayWriteAndRead() {
        store.todayStateDay = "2026-08-07"
        XCTAssertEqual(store.todayStateDay, "2026-08-07")
    }

    /// `stampTodayState` must produce exactly the format the reset compares
    /// against, or the guard silently never matches and the shield is lifted.
    func testStampTodayStateMatchesDayStampFormat() {
        let now = Date(timeIntervalSince1970: 1_786_104_000)
        store.stampTodayState(now: now, timeZone: TimeZone(identifier: "UTC")!)

        XCTAssertEqual(store.todayStateDay, "2026-08-07")
        XCTAssertEqual(
            store.todayStateDay,
            MidnightResetRecovery.dayStamp(for: now, timeZone: TimeZone(identifier: "UTC")!)
        )
    }

    /// The recorded shield set the app restores from. Opaque tokens can't be
    /// fabricated in tests, so this round-trips the storage itself.
    func testShieldedAppTokensWriteAndClear() {
        store.shieldedAppTokens = Data("blob".utf8)
        XCTAssertEqual(store.shieldedAppTokens, Data("blob".utf8))
        store.shieldedAppTokens = nil
        XCTAssertNil(store.shieldedAppTokens)
    }
}
