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
