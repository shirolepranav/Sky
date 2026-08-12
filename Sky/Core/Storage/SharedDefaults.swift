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
        /// The calendar day the three flags above describe. Lets a *late* midnight
        /// reset tell "these flags are yesterday's" from "these flags were written
        /// today, after midnight" — see MidnightResetRecovery.
        static let todayStateDay = "today_state_day"
        /// The application tokens actually shielded right now, so the app can
        /// re-apply exactly that set without re-shielding the whole selection.
        static let shieldedAppTokens = "shielded_app_tokens"
        static let verificationCompletedAt = "verification_completed_at"
        static let pendingDeepLink = "pending_deep_link"
        // Phase 12 — midnight-reset hand-off from DeviceActivityMonitor extension
        static let pendingMidnightReset = "streak_pending_midnight_reset"
        static let yesterdayDidVerify = "streak_yesterday_verified"
        static let yesterdayDidEmergency = "streak_yesterday_emergency"
        // Phase 15 — notification preferences, Night Mode, Pause, one-time primer
        // (`notif_morning_enabled` retired — the 8:30 morning nudge was removed.)
        static let notifWarningEnabled = "notif_warning_enabled"
        static let notifStreakEnabled = "notif_streak_enabled"
        /// `yyyy-MM-dd` of the last day each usage notification was posted. Written
        /// by the monitor extension; the only thing that stops iOS re-firing an
        /// already-crossed threshold from posting a duplicate.
        static let notifWarningDay = "notif_warning_day"
        static let notifBlockStartDay = "notif_blockstart_day"
        /// JSON `[String: Int]` — the highest session-ladder rung acted on today,
        /// keyed by "" (combined) or the app's base64 token (per-app).
        static let lastFiredRungs = "last_fired_rungs"
        static let nightModeEnabled = "night_mode_enabled"
        static let pauseStartedAt = "pause_started_at"
        static let lastPauseDate = "last_pause_date"
        static let notificationPrimerShown = "notif_primer_shown"
        // Phase 16 — appearance (light/dark/system) preference
        static let appearanceMode = "appearance_mode"
        // Re-arm guard for DeviceActivity monitoring (TIME_REMAINING_PLAN.md §2)
        static let monitoringConfigFingerprint = "monitoring_config_fingerprint"
        // iOS major version in force when the selection was last chosen. Detects the
        // silently-reissued-ApplicationToken case — see `selectionNeedsRedo`.
        static let selectionOSMajorVersion = "selection_os_major_version"
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

    /// `combinedLimitSeconds` as user-facing copy — "2 hours", "45 minutes".
    ///
    /// One place, because the same phrase appears on S-VER-06, S-TODAY-01 and
    /// S-CFG-03, and they have to agree about what a session actually buys.
    var sessionLengthLabel: String {
        let seconds = combinedLimitSeconds
        if seconds % 3600 == 0 {
            let hours = seconds / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let minutes = max(1, seconds / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
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

    /// `yyyy-MM-dd` (local) of the day the three flags above belong to.
    ///
    /// Written by whoever sets one of them — the monitor extension when it
    /// shields, `VerificationSuccessView` on unlock, the emergency flow. Empty
    /// means "no today-state has ever been written".
    ///
    /// This exists because `todayResetToken` alone can't distinguish a reset that
    /// is merely *late* from one that is due: a stale token plus a `todayStateDay`
    /// of today means the extension already moved the day on, and clearing the
    /// flags would undo a block applied minutes ago (the "Go outside" unlock bug).
    var todayStateDay: String {
        get { defaults.string(forKey: Key.todayStateDay) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.todayStateDay) }
    }

    /// Codable-archived `Set<ApplicationToken>` currently shielded, or nil when
    /// nothing is. Written by the monitor extension so `ShieldService.reconcile`
    /// can restore the exact set — in per-app mode only the apps that actually
    /// exhausted their own budget are shielded, and re-applying the whole
    /// selection would defeat the feature.
    var shieldedAppTokens: Data? {
        get { defaults.data(forKey: Key.shieldedAppTokens) }
        nonmutating set { defaults.set(newValue, forKey: Key.shieldedAppTokens) }
    }

    /// Stamps `todayStateDay` with the current local day. Call alongside any
    /// write to `isCurrentlyBlocked` / `didVerifyToday` / `didEmergencyUnlockToday`.
    nonmutating func stampTodayState(now: Date = Date(), timeZone: TimeZone = .current) {
        todayStateDay = MidnightResetRecovery.dayStamp(for: now, timeZone: timeZone)
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
    //
    // Sky posts at most two notifications a day, both consequences of the user's
    // own usage. The 8:30 "Good morning" nudge was removed deliberately: a daily
    // scheduled ping inviting you to pick up your phone works against an app whose
    // purpose is fewer interruptions. See LocalNotificationScheduler for the
    // migration that cancels the repeating request on already-installed devices.

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

    /// Day stamp of the last "30 minutes left" post, or "" if never.
    ///
    /// A `DeviceActivityEvent` threshold is supposed to fire once per interval, but
    /// iOS re-evaluates already-crossed thresholds whenever monitoring is re-armed
    /// with `includesPastActivity: true` — which a limit edit or an app-selection
    /// change triggers. Without a day stamp that replay posts a fresh notification
    /// at an arbitrary hour with no new usage behind it.
    var notifWarningDay: String {
        get { defaults.string(forKey: Key.notifWarningDay) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.notifWarningDay) }
    }

    /// Day stamp of the last "Time's up" post, or "" if never. See `notifWarningDay`.
    var notifBlockStartDay: String {
        get { defaults.string(forKey: Key.notifBlockStartDay) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.notifBlockStartDay) }
    }

    // MARK: Session ladder

    /// Raw JSON for `[String: Int]` — the highest session-ladder rung the monitor
    /// extension has acted on today, per ladder ("" = combined, base64 token =
    /// per-app). Written by the extension; the app only ever clears it, at the
    /// midnight reset.
    ///
    /// This is the high-water mark that makes a re-delivered threshold a no-op.
    /// See `DeviceActivityService`'s header for why the ladder exists at all.
    var lastFiredRungs: Data? {
        get { defaults.data(forKey: Key.lastFiredRungs) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastFiredRungs) }
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

    // MARK: DeviceActivity re-arm guard (TIME_REMAINING_PLAN.md §2)

    /// Digest of the configuration `.daily` monitoring was last registered with,
    /// or nil when nothing is armed. `DeviceActivityService.startMonitoring` skips
    /// re-registering while this matches the current configuration, so the
    /// every-foreground call in SkyApp can't restart the day's usage accumulation.
    ///
    /// App-side only — no extension reads it — but it lives here because it must
    /// survive relaunch alongside the configuration it describes.
    var monitoringConfigFingerprint: String? {
        get { defaults.string(forKey: Key.monitoringConfigFingerprint) }
        nonmutating set { defaults.set(newValue, forKey: Key.monitoringConfigFingerprint) }
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
            // Stamped so a later OS major change can be detected — see `selectionNeedsRedo`.
            selectionOSMajorVersion = newValue == nil ? 0 : Self.currentOSMajorVersion
        }
    }

    /// The iOS major version in force when `selection` was last written.
    /// `0` means "never stamped" — either no selection, or an install that predates
    /// this key (see `backfillSelectionOSVersionIfNeeded`).
    var selectionOSMajorVersion: Int {
        get { defaults.integer(forKey: Key.selectionOSMajorVersion) }
        nonmutating set { defaults.set(newValue, forKey: Key.selectionOSMajorVersion) }
    }

    static var currentOSMajorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    /// Adopts the current OS version for installs that stored a selection before this
    /// key existed. Without it every existing user would be told to re-pick apps on
    /// first launch after the update, having changed nothing. Call once at startup.
    func backfillSelectionOSVersionIfNeeded(
        currentOSMajor: Int = SharedDefaults.currentOSMajorVersion
    ) {
        guard familyActivitySelection != nil, selectionOSMajorVersion == 0 else { return }
        selectionOSMajorVersion = currentOSMajor
    }

    /// True when a non-empty selection is persisted *and* decodes cleanly.
    var hasSelection: Bool {
        guard let selection else { return false }
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    /// True when the persisted selection can no longer be trusted to refer to the
    /// user's actual apps, for either of two reasons:
    ///
    /// 1. The archive exists but no longer decodes.
    /// 2. The archive decodes fine, but iOS has had a **major version change** since
    ///    the user picked their apps.
    ///
    /// Case 2 is the one that matters and the one that is easy to miss. iOS reissues
    /// `ApplicationToken`s for the same apps from time to time, and the old tokens are
    /// left in place rather than invalidated. Because the archive is *our own* JSON,
    /// iOS never touches it — so it keeps decoding cleanly forever while the tokens
    /// inside quietly stop matching anything. Nothing else in the app can notice:
    /// `DeviceActivityService.startMonitoring` no-ops while the config fingerprint is
    /// unchanged, and stale tokens never fire a threshold, so the shield is simply
    /// never applied. The user sees "monitoring" and gets no blocking at all.
    ///
    /// There is no reliable way to detect reissuance directly, so this uses the OS
    /// major version as a proxy for "the most likely moment it happened". The cost is
    /// a false prompt after every annual iOS update; the alternative is a silent,
    /// permanent failure of the app's core function with no user-facing recovery.
    var selectionNeedsRedo: Bool {
        needsRedo(currentOSMajor: Self.currentOSMajorVersion)
    }

    /// Testable core of `selectionNeedsRedo`.
    func needsRedo(currentOSMajor: Int) -> Bool {
        guard familyActivitySelection != nil else { return false }
        if selection == nil { return true }
        let stamped = selectionOSMajorVersion
        guard stamped != 0 else { return false }  // never stamped — don't cry wolf
        return stamped != currentOSMajor
    }
}
