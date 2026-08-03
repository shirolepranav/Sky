// DebugSeeder.swift
// DEBUG-only demo-data factory for the S-SET-09 debug menu. Populates a rich,
// fully-loaded "Pro developer account" — maxed streak, all 10 badges, verification
// history, and an emergency/pause log — so every screen (Today, Streaks, Weekly
// Insights, Paywall's "Already Pro" variant) can be demoed with realistic data.
//
// Writes through the live managers (StreakManager / EmergencyLogStore / StoreKit /
// SharedDefaults) so the UI updates immediately. Never compiled into release.
// Sky_App_Workflow.md S-SET-09; Roadmap Phase 12/13/14.

#if DEBUG
import Foundation

@MainActor
enum DebugSeeder {

    // MARK: - One-tap

    /// Turn on Pro and fill every data category at once.
    /// `store` setters are `nonmutating` (write-through to the App Group), so a
    /// value parameter persists just like the caller's instance.
    static func applyFullProAccount(streakManager: StreakManager,
                                    storeKit: StoreKitService,
                                    store: SharedDefaults) {
        storeKit.debugSetPro(true)
        streakManager.debugReplaceProgress(seededProgress())
        EmergencyLogStore.shared.debugReplaceAll(seededEmergencyEntries())
        applyTodayState(store)
    }

    // MARK: - Granular category seeders

    static func unlockAllBadges(streakManager: StreakManager) {
        var p = streakManager.progress
        p.unlockedBadges = Set(BadgeID.allCases)
        streakManager.debugReplaceProgress(p)
    }

    static func set100DayStreak(streakManager: StreakManager) {
        var p = streakManager.progress
        p.currentStreak = 100
        p.longestStreak = max(p.longestStreak, 127)
        p.totalVerifications = max(p.totalVerifications, 143)
        p.lastVerificationDate = Date()
        streakManager.debugReplaceProgress(p)
    }

    static func seedEmergencyHistory() {
        EmergencyLogStore.shared.debugReplaceAll(seededEmergencyEntries())
    }

    /// Weekly Insights reads verification totals + this-week emergency reasons, so
    /// seed both to make that screen render fully.
    static func seedWeeklyInsights(streakManager: StreakManager) {
        set100DayStreak(streakManager: streakManager)
        EmergencyLogStore.shared.debugReplaceAll(seededEmergencyEntries())
    }

    // MARK: - Reset

    static func resetDemoData(streakManager: StreakManager,
                              storeKit: StoreKitService,
                              store: SharedDefaults) {
        storeKit.debugSetPro(false)
        streakManager.debugReplaceProgress(UserProgress())
        EmergencyLogStore.shared.debugClear()
        store.didVerifyToday = false
        store.didEmergencyUnlockToday = false
        store.isCurrentlyBlocked = false
    }

    // MARK: - Builders

    static func seededProgress() -> UserProgress {
        var p = UserProgress()
        p.currentStreak = 100
        p.longestStreak = 127
        p.totalVerifications = 143
        p.totalEmergencyUnlocks = 3
        p.lastVerificationDate = Date()
        p.firstInstallDate = Calendar.current.date(byAdding: .day, value: -150, to: Date()) ?? Date()
        p.unlockedBadges = Set(BadgeID.allCases)
        // Six distinct rounded "lat_lng" tags — drives the Wanderer badge / map.
        p.verificationLocations = ["37.77_-122.42", "37.80_-122.27", "34.05_-118.24",
                                   "40.71_-74.01", "47.61_-122.33", "51.51_-0.13"]
        p.hadEmergencyUnlock = true
        p.streakAfterFirstEmergency = 100
        p.mascotState = "sunny"
        return p
    }

    static func seededEmergencyEntries() -> [EmergencyUnlockEntry] {
        let cal = Calendar.current
        let now = Date()
        // (daysAgo, hour, reason, kind) — spread across this week and prior weeks,
        // with repeated reasons so `topReasonsThisWeek()` has clear winners.
        let samples: [(daysAgo: Int, hour: Int, reason: String, kind: EmergencyUnlockEntry.Kind)] = [
            (1,  9,  "Work deadline",        .emergency),
            (2,  14, "Family call",          .pause),
            (3,  21, "Travel day",           .emergency),
            (4,  8,  "Work deadline",        .emergency),
            (5,  19, "Doctor's appointment", .pause),
            (6,  12, "Family call",          .emergency),
            (9,  17, "Travel day",           .pause),
            (12, 10, "Work deadline",        .emergency),
            (15, 22, "Late night",           .emergency),
            (20, 7,  "Early meeting",        .pause),
        ]
        return samples.map { s in
            let date = cal.date(byAdding: .day, value: -s.daysAgo, to: now) ?? now
            return EmergencyUnlockEntry(
                id: UUID(),
                date: date,
                typedReason: s.reason,
                dayOfWeek: cal.component(.weekday, from: date),
                hourOfDay: s.hour,
                kind: s.kind
            )
        }
    }

    // MARK: - Shared today-state

    private static func applyTodayState(_ store: SharedDefaults) {
        store.didVerifyToday = true
        store.isCurrentlyBlocked = false
        store.limitMode = "perApp"
        store.combinedLimitSeconds = 3600
        store.limitsEnabled = true
        store.notifMorningEnabled = true
        store.notifWarningEnabled = true
        store.notifStreakEnabled = true
    }
}
#endif
