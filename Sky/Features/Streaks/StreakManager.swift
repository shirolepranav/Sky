// StreakManager.swift
// Owns all streak arithmetic: incrementing, resetting, milestone detection, and
// badge evaluation. Persists UserProgress locally and notifies CloudKitSyncService.
//
// Threading: @MainActor throughout — all callers (SkyApp, views) run on MainActor,
// and midnight-reset hand-off from the extension is consumed on foreground via
// SharedDefaults flags (the extension itself is sandboxed).
//
// Sky_App_Workflow.md §0.3 (mascot state machine), J-03, J-06, J-07;
// Technical Spec §6.2; Roadmap Phase 12.

import Foundation

@MainActor
final class StreakManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var progress: UserProgress

    // MARK: - Badge celebration queue (observed by TodayView)

    /// Badges earned in the most recent verification, not yet displayed.
    /// TodayView pops from this when the verification cover dismisses.
    @Published var pendingBadgeCelebrations: [BadgeID] = []

    // MARK: - Dependencies

    private let store: SharedDefaults
    private weak var cloudKit: CloudKitSyncService?

    // MARK: - Init

    init(store: SharedDefaults = SharedDefaults(), cloudKit: CloudKitSyncService? = nil) {
        self.store = store
        self.cloudKit = cloudKit
        self.progress = UserProgress.load()
    }

    /// Inject the CloudKitSyncService after construction (avoids circular init).
    func setCloudKit(_ service: CloudKitSyncService) {
        cloudKit = service
    }

    // MARK: - Public API

    /// Call on every foreground transition to consume the midnight-reset hand-off
    /// written by `SkyDeviceActivityMonitor.intervalDidStart` and, if needed,
    /// re-evaluate the streak for the previous day.
    func refreshOnForeground() {
        if store.pendingMidnightReset {
            let didVerifyYesterday = store.yesterdayDidVerify
            let didEmergencyYesterday = store.yesterdayDidEmergency
            store.pendingMidnightReset = false
            store.yesterdayDidVerify = false
            store.yesterdayDidEmergency = false
            handleMidnightReset(didVerifyYesterday: didVerifyYesterday,
                                didEmergencyYesterday: didEmergencyYesterday)
        }
    }

    /// Record a successful outdoor verification.
    ///
    /// - Parameters:
    ///   - locationTag: Rounded `"lat_lng"` string for Wanderer badge tracking, or nil.
    ///   - time: Wall-clock time of verification (for Early Bird check).
    /// - Returns: The new streak count and any badges earned for the first time.
    @discardableResult
    func handleVerificationSuccess(locationTag: String?, time: Date) -> (newStreak: Int, newBadges: [BadgeID]) {
        progress.totalVerifications += 1

        // Streak arithmetic — compare calendar days.
        let dayDelta = calendarDayDelta(from: progress.lastVerificationDate, to: time)
        switch dayDelta {
        case .some(1):    progress.currentStreak += 1        // consecutive day
        case .some(0):    break                              // same day, idempotent
        default:          progress.currentStreak = 1         // first ever or missed day(s)
        }

        progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
        progress.lastVerificationDate = time

        // Location for Wanderer badge
        if let tag = locationTag, !progress.verificationLocations.contains(tag) {
            progress.verificationLocations.append(tag)
        }

        // Comeback tracking — count clean days after the first emergency unlock
        if progress.hadEmergencyUnlock {
            progress.streakAfterFirstEmergency = progress.currentStreak
        }

        // Evaluate badges on the now-updated progress
        let newBadges = BadgeEngine.evaluate(progress: progress, verificationTime: time)
        for badge in newBadges {
            progress.unlockedBadges.insert(badge)
        }

        persist()
        return (progress.currentStreak, newBadges)
    }

    /// Record an emergency unlock: reset streak to 0, mark for Comeback tracking.
    func handleEmergencyUnlock() {
        progress.totalEmergencyUnlocks += 1
        progress.currentStreak = 0
        if !progress.hadEmergencyUnlock {
            progress.hadEmergencyUnlock = true
        }
        progress.streakAfterFirstEmergency = 0
        persist()
    }

    /// Evaluate yesterday's state and reset if necessary.
    /// Called by `refreshOnForeground()` when a midnight-reset hand-off is pending.
    func handleMidnightReset(didVerifyYesterday: Bool, didEmergencyYesterday: Bool) {
        // An emergency unlock already reset the streak; nothing to do for that path.
        // If neither verification nor emergency happened, the user silently skipped.
        if !didVerifyYesterday && !didEmergencyYesterday {
            progress.currentStreak = 0
        }
        persist()
    }

    /// Returns true when `n` is a streak milestone that deserves a celebration.
    /// The list lives in `StreakInsights.milestones` so the Streaks tab's
    /// "next milestone" progress and this check can never drift apart.
    func isMilestoneStreak(_ n: Int) -> Bool {
        StreakInsights.milestones.contains(n)
    }

    #if DEBUG
    /// Debug-menu (S-SET-09) seed hook — replace the live progress and persist it,
    /// so the UI updates immediately (writing UserDefaults alone would not refresh
    /// the `@Published` value). Never compiled into release.
    func debugReplaceProgress(_ newProgress: UserProgress) {
        progress = newProgress
        persist()
    }
    #endif

    // MARK: - Private

    private func persist() {
        progress.save()
        cloudKit?.scheduleSave(progress)
    }

    /// Calendar-day distance between two dates in the user's local timezone.
    /// Returns nil when `from` is nil (first ever verification).
    private func calendarDayDelta(from: Date?, to: Date) -> Int? {
        guard let from else { return nil }
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay   = cal.startOfDay(for: to)
        let components = cal.dateComponents([.day], from: fromDay, to: toDay)
        return components.day
    }
}
