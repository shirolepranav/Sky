// UserProgress.swift
// Local-first model of the user's streak, badge, and lifetime stats.
// Mirrors the CloudKit `UserProgress` record schema (Technical Spec §6.2) and is
// persisted to `UserDefaults.standard` as JSON so it's readable on next launch
// without waiting for CloudKit. CloudKitSyncService keeps both copies in sync.
//
// All CloudKit-level field names (the CKRecord keys) are listed in the CK enum
// so they are defined in one place and never inline-duplicated.
//
// Phase 12 — Roadmap Phase 12.

import Foundation

// MARK: - User progress model

struct UserProgress: Codable, Equatable {

    // MARK: Streak counters
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalVerifications: Int = 0
    var totalEmergencyUnlocks: Int = 0

    // MARK: Dates
    var lastVerificationDate: Date?
    var firstInstallDate: Date = Date()

    // MARK: Badges
    /// IDs of badges that have been earned. Conflict resolution: union across devices.
    var unlockedBadges: Set<BadgeID> = []

    // MARK: Locations for Wanderer badge
    /// "lat_lng" strings rounded to 0.01° (≈1 km). Deduplicated.
    var verificationLocations: [String] = []

    // MARK: Mascot (synced so a second device shows the right state)
    var mascotState: String = "fluffyWhite"

    // MARK: Comeback badge tracking
    /// Set to true on the first emergency unlock; never reverted.
    var hadEmergencyUnlock: Bool = false
    /// Count of consecutive clean days accrued since the first emergency unlock.
    var streakAfterFirstEmergency: Int = 0

    // MARK: CloudKit field-name constants

    enum CKField {
        static let currentStreak              = "currentStreak"
        static let longestStreak              = "longestStreak"
        static let totalVerifications         = "totalVerifications"
        static let totalEmergencyUnlocks      = "totalEmergencyUnlocks"
        static let lastVerificationDate       = "lastVerificationDate"
        static let firstInstallDate           = "firstInstallDate"
        static let unlockedBadges             = "unlockedBadges"
        static let verificationLocations      = "verificationLocations"
        static let mascotState                = "mascotState"
        static let hadEmergencyUnlock         = "hadEmergencyUnlock"
        static let streakAfterFirstEmergency  = "streakAfterFirstEmergency"
    }
}

// MARK: - UserDefaults persistence

extension UserProgress {
    private static let defaultsKey = "userProgress"

    /// Load from UserDefaults.standard, or return a fresh default.
    static func load() -> UserProgress {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let progress = try? JSONDecoder().decode(UserProgress.self, from: data)
        else { return UserProgress() }
        return progress
    }

    /// Persist to UserDefaults.standard.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
