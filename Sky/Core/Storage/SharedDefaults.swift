// SharedDefaults.swift
// Single source of cross-process state shared by the main app and the three
// extensions through the App Group (Technical Spec §6.1, App Group
// `group.com.shirolepranav.sky`).
//
// Implemented as a struct over an *injectable* `UserDefaults` suite (default =
// the App Group suite) rather than a fixed-suite property wrapper, mirroring the
// injection pattern in OnboardingViewModel so unit tests can use an isolated
// suite. The App Group identifier lives in one constant (`suiteName`) — never
// inline it elsewhere.
//
// Phase 3 only exercises `familyActivitySelection` / `selection`. The remaining
// keys are declared now so this stays the one place shared state is defined;
// later phases (5, 10, 12, 13) read/write the already-present properties.

import Foundation
import FamilyControls

struct SharedDefaults {
    /// The App Group suite shared by all four targets.
    static let suiteName = "group.com.shirolepranav.sky"

    /// Backing store. Defaults to the App Group suite; tests inject an isolated one.
    let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    // MARK: Keys
    private enum Key {
        static let selection = "selection"
        static let limitMode = "limitMode"
        static let combinedLimitSeconds = "combinedLimitSeconds"
        static let perAppLimits = "perAppLimits"
        static let limitsEnabled = "limitsEnabled"
        static let isCurrentlyBlocked = "today_blocked"
        static let didVerifyToday = "today_verified"
        static let didEmergencyUnlockToday = "today_emergency_used"
        static let todayResetToken = "today_reset_token"
        static let verificationCompletedAt = "verification_completed_at"
        static let pendingDeepLink = "pending_deep_link"
        // Phase 12 — midnight-reset hand-off from DeviceActivityMonitor extension
        static let pendingMidnightReset = "streak_pending_midnight_reset"
        static let yesterdayDidVerify = "streak_yesterday_verified"
        static let yesterdayDidEmergency = "streak_yesterday_emergency"
        // Phase 15 — notification preferences, Night Mode, Pause, one-time primer
        static let notifMorningEnabled = "notif_morning_enabled"
        static let notifWarningEnabled = "notif_warning_enabled"
        static let notifStreakEnabled = "notif_streak_enabled"
        static let nightModeEnabled = "night_mode_enabled"
        static let pauseStartedAt = "pause_started_at"
        static let lastPauseDate = "last_pause_date"
        static let notificationPrimerShown = "notif_primer_shown"
        // Phase 16 — appearance (light/dark/system) preference
        static let appearanceMode = "appearance_mode"
    }

    // MARK: Configuration (written by main app, read by extensions)

    /// Codable-archived `FamilyActivitySelection`. Prefer the typed `selection`
    /// accessor below; this is the raw storage.
    var familyActivitySelection: Data? {
        get { defaults.data(forKey: Key.selection) }
        nonmutating set { defaults.set(newValue, forKey: Key.selection) }
    }

    var limitMode: String {
        get { defaults.string(forKey: Key.limitMode) ?? "combined" }
        nonmutating set { defaults.set(newValue, forKey: Key.limitMode) }
    }

    var combinedLimitSeconds: Int {
        get { defaults.object(forKey: Key.combinedLimitSeconds) as? Int ?? 7200 }
        nonmutating set { defaults.set(newValue, forKey: Key.combinedLimitSeconds) }
    }

    var perAppLimitsData: Data? {
        get { defaults.data(forKey: Key.perAppLimits) }
        nonmutating set { defaults.set(newValue, forKey: Key.perAppLimits) }
    }

    var limitsEnabled: Bool {
        get { defaults.object(forKey: Key.limitsEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.limitsEnabled) }
    }

    // MARK: Today state (written by extensions, read by main app)

    var isCurrentlyBlocked: Bool {
        get { defaults.bool(forKey: Key.isCurrentlyBlocked) }
        nonmutating set { defaults.set(newValue, forKey: Key.isCurrentlyBlocked) }
    }

    var didVerifyToday: Bool {
        get { defaults.bool(forKey: Key.didVerifyToday) }
        nonmutating set { defaults.set(newValue, forKey: Key.didVerifyToday) }
    }

    var didEmergencyUnlockToday: Bool {
        get { defaults.bool(forKey: Key.didEmergencyUnlockToday) }
        nonmutating set { defaults.set(newValue, forKey: Key.didEmergencyUnlockToday) }
    }

    var todayResetToken: String {
        get { defaults.string(forKey: Key.todayResetToken) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.todayResetToken) }
    }

    // MARK: Hand-off (written by main app post-verification)

    var verificationCompletedAt: Date? {
        get { defaults.object(forKey: Key.verificationCompletedAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.verificationCompletedAt) }
    }

    // MARK: Phase 12 — midnight-reset hand-off (written by DeviceActivityMonitor, consumed by StreakManager)

    /// Set by the extension at midnight before clearing today's flags.
    /// StreakManager reads and clears this on the next foreground transition.
    var pendingMidnightReset: Bool {
        get { defaults.bool(forKey: Key.pendingMidnightReset) }
        nonmutating set { defaults.set(newValue, forKey: Key.pendingMidnightReset) }
    }

    /// Yesterday's `didVerifyToday` value captured just before the midnight clear.
    var yesterdayDidVerify: Bool {
        get { defaults.bool(forKey: Key.yesterdayDidVerify) }
        nonmutating set { defaults.set(newValue, forKey: Key.yesterdayDidVerify) }
    }

    /// Yesterday's `didEmergencyUnlockToday` value captured just before the midnight clear.
    var yesterdayDidEmergency: Bool {
        get { defaults.bool(forKey: Key.yesterdayDidEmergency) }
        nonmutating set { defaults.set(newValue, forKey: Key.yesterdayDidEmergency) }
    }

    // MARK: Shield action hand-off (written by ShieldActionExtension, consumed by main app)

    /// The deep-link destination a shield button requested ("verify" or
    /// "emergency"), or nil when none is pending. The ShieldActionExtension can't
    /// open the app directly (UIApplication.shared is unavailable in extensions),
    /// so SkyApp reads and clears this on becoming active to present the screen
    /// (Sky_App_Workflow.md S-SHIELD-02 / S-SHIELD-03).
    var pendingDeepLink: String? {
        get { defaults.string(forKey: Key.pendingDeepLink) }
        nonmutating set { defaults.set(newValue, forKey: Key.pendingDeepLink) }
    }

    // MARK: Phase 15 — Notification preferences (opt-out; default ON)

    /// Morning "hello" at 8:30 AM. Scheduled app-side by LocalNotificationScheduler.
    var notifMorningEnabled: Bool {
        get { defaults.object(forKey: Key.notifMorningEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.notifMorningEnabled) }
    }

    /// 30-minutes-before-block warning. Posted by the DeviceActivityMonitor
    /// extension when the paired warning threshold fires (read cross-process).
    var notifWarningEnabled: Bool {
        get { defaults.object(forKey: Key.notifWarningEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.notifWarningEnabled) }
    }

    /// 10 PM streak-at-risk reminder. Pro-gated at the UI/scheduler level.
    var notifStreakEnabled: Bool {
        get { defaults.object(forKey: Key.notifStreakEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.notifStreakEnabled) }
    }

    // MARK: Phase 15 — Night Mode (opt-in; default OFF)

    /// When true, the daylight (sunrise/sunset) verification check is bypassed
    /// (all other checks still apply). Read by VerificationDecisionEngine.
    var nightModeEnabled: Bool {
        get { defaults.bool(forKey: Key.nightModeEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.nightModeEnabled) }
    }

    // MARK: Phase 15 — Pause Sky (Pro, max once/week)

    /// Timestamp a 24-hour pause began, or nil when never paused. The pause is
    /// considered active for 24h after this instant — see `isPaused`.
    var pauseStartedAt: Date? {
        get { defaults.object(forKey: Key.pauseStartedAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.pauseStartedAt) }
    }

    /// The most recent pause start, retained past expiry to enforce the
    /// once-per-week limit even after the pause window closes.
    var lastPauseDate: Date? {
        get { defaults.object(forKey: Key.lastPauseDate) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastPauseDate) }
    }

    /// True while a 24-hour pause is still in effect. Extensions read this to
    /// skip applying shields; the main app shows the "Paused until…" banner.
    var isPaused: Bool {
        guard let start = pauseStartedAt else { return false }
        return Date().timeIntervalSince(start) < 24 * 60 * 60
    }

    /// The instant the current pause expires, or nil when not paused.
    var pauseEndsAt: Date? {
        guard isPaused, let start = pauseStartedAt else { return nil }
        return start.addingTimeInterval(24 * 60 * 60)
    }

    /// True when a new 24-hour pause is allowed — never paused, or ≥7 days since
    /// the last pause began (S-SET-03 once-per-week limit).
    var canPauseNow: Bool {
        guard let last = lastPauseDate else { return true }
        return Date().timeIntervalSince(last) >= 7 * 24 * 60 * 60
    }

    /// When the next pause becomes available, or nil when one is available now.
    var nextPauseAvailableDate: Date? {
        guard let last = lastPauseDate, !canPauseNow else { return nil }
        return last.addingTimeInterval(7 * 24 * 60 * 60)
    }

    // MARK: Phase 15 — one-time notification permission primer (S-PERM-03)

    /// True once the notification-rationale primer has been shown, so it appears
    /// only once after first setup.
    var notificationPrimerShown: Bool {
        get { defaults.bool(forKey: Key.notificationPrimerShown) }
        nonmutating set { defaults.set(newValue, forKey: Key.notificationPrimerShown) }
    }

    // MARK: Phase 16 — Appearance (light / dark / system; default system)

    /// The user's appearance choice as a raw string ("system" / "light" / "dark").
    /// Prefer the typed `AppearanceManager`; this is the raw storage. Defaults to
    /// "system" so the app follows the device setting until the user picks otherwise.
    var appearanceModeRaw: String {
        get { defaults.string(forKey: Key.appearanceMode) ?? "system" }
        nonmutating set { defaults.set(newValue, forKey: Key.appearanceMode) }
    }

    // MARK: Typed selection accessor

    /// The persisted app/category selection, hiding the Codable archiving.
    ///
    /// Returns `nil` when nothing is stored *or* when the stored Data fails to
    /// decode — the latter is the iOS-upgrade-invalidated-token case the app
    /// surfaces to the user (S-CFG-01 "needs redoing after an iOS update").
    /// `FamilyActivitySelection` conforms to `Codable` (Tech Spec §7.2).
    var selection: FamilyActivitySelection? {
        get {
            guard let data = familyActivitySelection else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        nonmutating set {
            familyActivitySelection = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    /// True when a non-empty selection is persisted *and* decodes cleanly.
    var hasSelection: Bool {
        guard let selection else { return false }
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    /// True when Data exists but failed to decode (stale tokens after an iOS update).
    var selectionNeedsRedo: Bool {
        familyActivitySelection != nil && selection == nil
    }
}
