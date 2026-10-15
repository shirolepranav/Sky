// LockPolicy.swift
// The one rule for "should the morning lock apply now?" (DAILY_LOCK_PLAN.md Phase B).
//
// Two callers apply it:
//   • SkyDeviceActivityMonitor, at `.lock` intervalDidStart (the normal path).
//     ⚠️ It cannot import this module and mirrors `shouldLock` inline — keep both
//     in sync.
//   • ShieldService.reconcile, as a catch-up when that callback was missed or
//     ignored (see `armGraceSeconds`).

import Foundation

enum LockPolicy {

    /// A `.lock` interval start this soon after registering the schedule is iOS
    /// announcing the registration, not the day's lock — the extension ignores it.
    /// Registration only ever happens with Sky in the foreground, so the app-side
    /// catch-up applies the lock instead when it is genuinely due.
    static let armGraceSeconds: TimeInterval = 60

    /// Whether the lock applies today at all, ignoring the time of day.
    ///
    /// `skipDay` is the day setup finished after that day's lock time — someone who
    /// finishes onboarding at 10 AM with a 9 AM lock isn't locked out on the spot.
    static func shouldLock(
        now: Date,
        isPaused: Bool,
        unlockedToday: Bool,
        lockWeekdays: Set<Int>,
        skipDay: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard !isPaused, !unlockedToday else { return false }
        guard lockWeekdays.contains(calendar.component(.weekday, from: now)) else { return false }
        return MidnightResetRecovery.dayStamp(for: now, timeZone: calendar.timeZone) != skipDay
    }

    /// Today's lock instant.
    static func lockInstant(on day: Date, lockTimeMinutes: Int, calendar: Calendar = .current) -> Date {
        // bySettingHour, not startOfDay + seconds, so a DST-change day still locks
        // at the wall-clock time the user picked.
        calendar.date(
            bySettingHour: lockTimeMinutes / 60, minute: lockTimeMinutes % 60, second: 0, of: day
        ) ?? calendar.startOfDay(for: day)
    }

    /// True when today's lock time has passed and the lock should be in force.
    /// The caller only acts when it isn't — i.e. the extension's callback was
    /// missed, or ignored inside the arm grace window.
    ///
    /// Never true before monitoring was first armed (setup still in progress).
    static func lockIsOverdue(
        now: Date,
        lockTimeMinutes: Int,
        isArmed: Bool,
        isPaused: Bool,
        unlockedToday: Bool,
        lockWeekdays: Set<Int>,
        skipDay: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard isArmed else { return false }
        guard now >= lockInstant(on: now, lockTimeMinutes: lockTimeMinutes, calendar: calendar) else {
            return false
        }
        return shouldLock(
            now: now,
            isPaused: isPaused,
            unlockedToday: unlockedToday,
            lockWeekdays: lockWeekdays,
            skipDay: skipDay,
            calendar: calendar
        )
    }
}
