// MidnightResetRecovery.swift
// App-side safety net for the daily midnight reset (Sky_App_Workflow.md J-06;
// Technical Spec §7.4).
//
// `SkyDeviceActivityMonitor.intervalDidStart` normally performs the reset at
// 00:00. DeviceActivity callbacks are not guaranteed — the device can be off,
// monitoring can be torn down, and the callback is historically flaky — and when
// it is missed nothing else clears the day's flags. The user then stays shielded
// past midnight with no route back except verifying again, or `didVerifyToday`
// survives into the next day and leaves the apps open.
//
// `todayResetToken` already existed for exactly this purpose ("invalidates stale
// cached state") but nothing ever read it. This is the reader.
//
// ⚠️ This duplicates the reset that `intervalDidStart` performs. The two must
// agree, and must never both run for the same day: `handleMidnightReset` zeroes
// the streak when neither a verification nor an emergency unlock happened, so a
// second pass over already-cleared flags would wrongly break a live streak. The
// day stamp is what makes the reset idempotent — whoever gets there first writes
// it, and the other side then no-ops.
//
// ⚠️ This runs on every foreground, so it is *late* by definition — anywhere from
// a second to a day after the midnight it stands in for. It must therefore never
// clear state that belongs to the current day. `todayStateDay` is the guard: see
// the `.stampOnly` branch. Getting this wrong lifts a live shield, which is the
// one failure this app cannot have.

import Foundation

enum MidnightResetRecovery {

    /// What `runIfNeeded` did, so callers and tests can tell the cases apart.
    enum Outcome: Equatable {
        /// The stamp is today — the extension already reset, nothing to do.
        case upToDate
        /// No stamp stored yet (fresh install). The stamp is adopted *without* a
        /// streak hand-off: there is no previous day to evaluate, and pretending
        /// otherwise would zero the streak of anyone restoring a backup.
        case adoptedFirstStamp
        /// The stamp was stale — the reset ran here instead of in the extension.
        case recovered
        /// The stamp was stale but today's state was already written by the
        /// extension after midnight. The stamp is advanced and *nothing else is
        /// touched* — see the `todayStateDay` discussion below.
        case stampOnly
        /// The stamp is a day in the future (clock moved back, or travel across
        /// the date line). Adopted without clearing anything: going backwards in
        /// time must never lift a shield.
        case adoptedFutureStamp
    }

    /// `YYYY-MM-DD` in the given time zone.
    ///
    /// Deliberately **local** time. `DeviceActivitySchedule` starts its interval at
    /// local midnight, so the stamp has to be a local calendar day or it is wrong
    /// by one for a large part of the world.
    ///
    /// ⚠️ `SkyDeviceActivityMonitor` mirrors this (it cannot import the Sky
    /// module). Both must produce byte-identical strings — keep them in sync.
    static func dayStamp(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parses a stamp produced by `dayStamp(for:timeZone:)` back to a date, or nil
    /// if it isn't one. Used to tell "behind today" from "ahead of today" — a
    /// plain `!=` cannot, and treating a future stamp as stale would run a reset
    /// (and clear a live shield) every time a clock moved backwards.
    static func date(fromDayStamp stamp: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: stamp)
    }

    /// Runs the midnight reset if the stored day stamp isn't today.
    ///
    /// Must be called *before* `StreakManager.refreshOnForeground()` so the
    /// hand-off it writes is consumed in the same foreground pass, and before
    /// anything reads today's flags.
    ///
    /// - Parameter clearShields: injected so tests don't touch ManagedSettings.
    @discardableResult
    static func runIfNeeded(
        store: SharedDefaults = SharedDefaults(),
        now: Date = Date(),
        timeZone: TimeZone = .current,
        clearShields: () -> Void = { ShieldService.unlockApps(source: .midnightRecovery) }
    ) -> Outcome {
        let today = dayStamp(for: now, timeZone: timeZone)
        let stored = store.todayResetToken

        if stored == today { return .upToDate }

        // Fresh install (or a wipe): adopt today without inventing a yesterday.
        guard !stored.isEmpty else {
            store.todayResetToken = today
            return .adoptedFirstStamp
        }

        // A stamp *ahead* of today isn't stale — the clock moved backwards, or the
        // user crossed the date line westward. Adopt it and touch nothing else.
        if let storedDate = date(fromDayStamp: stored, timeZone: timeZone),
           let todayDate = date(fromDayStamp: today, timeZone: timeZone),
           storedDate > todayDate {
            store.todayResetToken = today
            return .adoptedFutureStamp
        }

        // The reset is *late*, so the flags it is about to clear may not be
        // yesterday's at all. `todayStateDay` records which day they describe: the
        // monitor extension stamps it when it shields, verification and emergency
        // unlock stamp it when they open the apps back up.
        //
        // If it already says today, the extension has moved the day on and this
        // state was written after midnight. Clearing it here would undo a block
        // that landed minutes ago — the bug where tapping "Go outside to unlock"
        // opened the apps, because that tap is what brings Sky to the foreground.
        // Advance the stamp so the two sides agree, and leave everything else be.
        if store.todayStateDay == today {
            store.todayResetToken = today
            return .stampOnly
        }

        // Mirrors intervalDidStart, in the same order: snapshot yesterday's flags
        // for StreakManager *before* clearing them.
        store.yesterdayDidVerify = store.didVerifyToday
        store.yesterdayDidEmergency = store.didEmergencyUnlockToday
        store.pendingMidnightReset = true

        clearShields()

        store.isCurrentlyBlocked = false
        store.didVerifyToday = false
        store.didEmergencyUnlockToday = false
        store.todayStateDay = today
        store.todayResetToken = today

        return .recovered
    }
}
