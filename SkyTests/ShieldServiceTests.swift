// ShieldServiceTests.swift
// Covers the decision half of ShieldService.reconcile — "should the apps be
// shielded right now, according to today's persisted state?"
//
// The apply/clear half writes to ManagedSettingsStore, which needs the Family
// Controls entitlement and a real device, so it is not exercised here. The
// decision is what carries the risk: a false positive locks a user out of apps
// they have earned back, and a false negative is the "Go outside to unlock"
// bug — the shield silently staying down for the rest of the day.

import XCTest
@testable import Sky

final class ShieldServiceTests: XCTestCase {

    private var suiteName = ""
    private var store = SharedDefaults()

    override func setUp() {
        super.setUp()
        suiteName = "sky.tests.\(UUID().uuidString)"
        store = SharedDefaults(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: shouldBeBlocked

    /// The state the bug left behind: the day says blocked, nothing has unlocked
    /// it, so a missing shield must be restored.
    func testBlockedAndUnverifiedShouldBeBlocked() {
        store.isCurrentlyBlocked = true

        XCTAssertTrue(ShieldService.shouldBeBlocked(store: store))
    }

    /// Never re-shield a day that was never blocked.
    func testNotBlockedShouldNotBeBlocked() {
        store.isCurrentlyBlocked = false

        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    /// A verification buys one *session*, not the rest of the day, so
    /// `didVerifyToday` must not suppress the shield. It used to, and that was what
    /// made a single 30-second video at 9am open the apps until midnight.
    ///
    /// The unlock itself is expressed by `isCurrentlyBlocked = false` (written by
    /// `VerificationSuccessView.performUnlock`). When the next ladder rung fires and
    /// sets the flag again, the shield has to come back even though the user did
    /// verify earlier today.
    func testVerifiedTodayDoesNotSuppressALaterSessionBlock() {
        store.isCurrentlyBlocked = true
        store.didVerifyToday = true

        XCTAssertTrue(
            ShieldService.shouldBeBlocked(store: store),
            "a verification earlier today must not keep the next session unlocked"
        )
    }

    /// The other half of that: immediately after verifying, the flag is down and
    /// nothing re-shields until the next rung.
    func testVerificationUnlockIsRespectedUntilTheNextRung() {
        store.isCurrentlyBlocked = false
        store.didVerifyToday = true

        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    /// The emergency unlock already cost the user their streak; it must not also
    /// be undone by reconciliation.
    ///
    /// Unlike a verification this covers the whole day. Re-locking someone every
    /// two hours who has told us they cannot get outside — and making them retype a
    /// reason each time — is punishment rather than friction.
    func testEmergencyUnlockedTodayShouldNotBeBlocked() {
        store.isCurrentlyBlocked = true
        store.didEmergencyUnlockToday = true

        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    /// Pause outranks everything, matching the monitor extension's own ordering.
    func testActivePauseShouldNotBeBlocked() {
        store.isCurrentlyBlocked = true
        store.pauseStartedAt = Date()

        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    /// ...but an expired pause stops protecting: a 25-hour-old pause is over.
    func testExpiredPauseShouldBeBlocked() {
        store.isCurrentlyBlocked = true
        store.pauseStartedAt = Date().addingTimeInterval(-25 * 60 * 60)

        XCTAssertTrue(ShieldService.shouldBeBlocked(store: store))
    }

    // MARK: tokensToRestore

    /// Per-app mode with no recorded token set: we cannot tell which app ran out
    /// of budget, and shielding the whole selection would lock apps still well
    /// inside their own limit. Restoring nothing is the correct answer — the next
    /// threshold event will shield the right one.
    func testPerAppModeWithoutRecordedTokensRestoresNothing() {
        store.limitMode = "perApp"
        store.shieldedAppTokens = nil

        XCTAssertTrue(ShieldService.tokensToRestore(store: store).isEmpty)
    }

    /// Combined mode with no selection has nothing to shield either.
    func testCombinedModeWithoutSelectionRestoresNothing() {
        store.limitMode = "combined"
        store.familyActivitySelection = nil

        XCTAssertTrue(ShieldService.tokensToRestore(store: store).isEmpty)
        XCTAssertTrue(ShieldService.categoriesToRestore(store: store).isEmpty)
    }

    /// Categories carry no per-app budget, so per-app mode never restores them
    /// even when the selection has some.
    func testPerAppModeRestoresNoCategories() {
        store.limitMode = "perApp"

        XCTAssertTrue(ShieldService.categoriesToRestore(store: store).isEmpty)
    }

    /// Corrupt persisted data must not throw or resurrect a wrong set — it falls
    /// through to the combined-mode path, which is empty without a selection.
    func testUndecodableTokenBlobIsIgnored() {
        store.limitMode = "combined"
        store.shieldedAppTokens = Data("not json".utf8)

        XCTAssertTrue(ShieldService.tokensToRestore(store: store).isEmpty)
    }
}
