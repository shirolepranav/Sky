// ShieldService.swift
// Named wrapper around ManagedSettingsStore shield operations so shield
// clearing is never duplicated inline (Tech Spec §7.6; DAILY_LOCK_PLAN.md Phase B).
//
// The shield is normally *applied* by SkyDeviceActivityMonitor at the daily lock
// time, in another process, on a callback that fires once a day. Anything that
// drops the shield — an OS quirk, an invalidated token — or a missed callback
// would leave the apps open, because nothing else puts it back.
//
// `reconcile` closes that. Today's persisted state is the authority on whether
// apps should be blocked; the ManagedSettings store is just a cache of it, and
// every foreground repairs the cache. Clearing stays exclusive to `unlockApps`,
// so reconciliation can only ever make the app *more* strict.

import Foundation
import FamilyControls
import ManagedSettings

enum ShieldService {

    /// Clears all active application and category shields, opening the selected
    /// apps until the next daily lock.
    ///
    /// The legitimate callers are a passed verification, a completed emergency
    /// unlock, a Pro pause, and the debug menu. `source` is recorded so any other
    /// caller is visible on-device.
    ///
    /// ⚠️ Keep assigning `nil` rather than subtracting a token set — the nil also
    /// clears orphaned tokens iOS has silently reissued (see CLAUDE.md Gotchas).
    static func unlockApps(source: ShieldAudit.Source) {
        let managed = ManagedSettingsStore()
        managed.shield.applications = nil
        managed.shield.applicationCategories = nil
        ShieldAudit.record(.cleared, source: source, appCount: 0)
    }

    /// Shields the whole selection. Mirrors the write in
    /// `SkyDeviceActivityMonitor.applyLock`.
    static func applyShield(selection: FamilyActivitySelection, source: ShieldAudit.Source) {
        let managed = ManagedSettingsStore()
        let tokens = selection.applicationTokens
        managed.shield.applications = tokens.isEmpty ? nil : tokens
        managed.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        ShieldAudit.record(.applied, source: source, appCount: tokens.count)
    }

    /// Brings the shield in line with today's state, on every foreground and
    /// whenever the verification flow is left without a pass.
    ///
    /// 1. If today's lock is overdue — the extension's lock-time callback never
    ///    ran — mark the day blocked (`LockPolicy.lockIsOverdue`).
    /// 2. If the day is blocked but the ManagedSettings store isn't shielding,
    ///    re-apply.
    ///
    /// Never clears: a `false` here means "leave it alone", not "unshield".
    ///
    /// - Returns: true if a shield was (re-)applied.
    @discardableResult
    static func reconcile(store: SharedDefaults = SharedDefaults(), now: Date = Date()) -> Bool {
        guard let selection = store.selection else { return false }

        let caughtUp = catchUpMissedLock(store: store, now: now)
        guard shouldBeBlocked(store: store) else { return false }

        let managed = ManagedSettingsStore()
        let alreadyShielded = (managed.shield.applications ?? [])
            .isSuperset(of: selection.applicationTokens)
            && (selection.categoryTokens.isEmpty || managed.shield.applicationCategories != nil)
        guard !alreadyShielded else { return false }

        applyShield(selection: selection, source: caughtUp ? .lockCatchUp : .reconcile)
        return true
    }

    // MARK: - Decision (internal so unit tests can drive it without ManagedSettings)

    /// Sets `isCurrentlyBlocked` when today's lock is overdue. Returns true if it did.
    @discardableResult
    static func catchUpMissedLock(store: SharedDefaults, now: Date = Date()) -> Bool {
        guard !store.isCurrentlyBlocked else { return false }
        // Roll over first so yesterday's verification can't count as today's.
        MidnightResetRecovery.rollDayOverBeforeWritingTodayState(store: store, now: now)
        let overdue = LockPolicy.lockIsOverdue(
            now: now,
            lockTimeMinutes: store.lockTimeMinutes,
            isArmed: store.lockArmedAt != nil,
            isPaused: store.isPaused,
            unlockedToday: store.didVerifyToday || store.didEmergencyUnlockToday,
            lockWeekdays: store.lockWeekdays,
            skipDay: store.lockSkipDay
        )
        guard overdue else { return false }
        store.isCurrentlyBlocked = true
        store.stampTodayState(now: now)
        return true
    }

    /// Today's state, in one place. A pause outranks the block.
    ///
    /// Verification and emergency unlock both clear `isCurrentlyBlocked`
    /// themselves, and it stays clear until the next lock time — so neither needs
    /// consulting here.
    static func shouldBeBlocked(store: SharedDefaults) -> Bool {
        store.isCurrentlyBlocked && !store.isPaused
    }
}
