// BadgeEngine.swift
// Stateless badge condition evaluator and the BadgeID enum.
// Called by StreakManager after every successful verification to determine
// which (if any) badges were just earned.
//
// All badge copy lives here alongside the IDs so they stay in lockstep.
// Sky_App_Workflow.md §Group C S-STREAK-02/03; Roadmap Phase 12.

import Foundation

// MARK: - Badge identifier

/// The 10 launch badges (PRD §4.8). Raw values are stable identifiers stored
/// in CloudKit and UserDefaults — never rename them.
enum BadgeID: String, Codable, CaseIterable, Hashable, Identifiable {
    var id: String { rawValue }
    case firstLight
    case cumulus
    case stratus
    case cirrus
    case sunburst
    case clearSky
    case boundless
    case earlyBird
    case wanderer
    case comeback
}

// MARK: - Badge metadata

extension BadgeID {
    var displayName: String {
        switch self {
        case .firstLight: return "First Light"
        case .cumulus:    return "Cumulus"
        case .stratus:    return "Stratus"
        case .cirrus:     return "Cirrus"
        case .sunburst:   return "Sunburst"
        case .clearSky:   return "Clear Sky"
        case .boundless:  return "Boundless"
        case .earlyBird:  return "Early Bird"
        case .wanderer:   return "Wanderer"
        case .comeback:   return "Comeback"
    }
    }

    var description: String {
        switch self {
        case .firstLight: return "You did it. Your first outdoor verification."
        case .cumulus:    return "Three days in a row. Real momentum."
        case .stratus:    return "A whole week. The hard part is starting; you're past it."
        case .cirrus:     return "Two weeks. It's becoming who you are."
        case .sunburst:   return "Thirty days. Sky's proud of you."
        case .clearSky:   return "Sixty straight days outside."
        case .boundless:  return "One hundred days. Most apps never see numbers like this."
        case .earlyBird:  return "Verified before 8 AM — you caught the morning light."
        case .wanderer:   return "Five different places verified. Touch lots of grass."
        case .comeback:   return "Used an emergency unlock, then strung together 7 clean days. That's character."
        }
    }

    /// SF Symbol name used for badge artwork.
    var symbolName: String {
        switch self {
        case .firstLight: return "sun.max.fill"
        case .cumulus:    return "flame.fill"
        case .stratus:    return "flame.fill"
        case .cirrus:     return "flame.fill"
        case .sunburst:   return "flame.fill"
        case .clearSky:   return "flame.fill"
        case .boundless:  return "flame.fill"
        case .earlyBird:  return "sunrise.fill"
        case .wanderer:   return "figure.walk"
        case .comeback:   return "arrow.turn.up.right"
        }
    }

    /// Canonical display order in S-STREAK-02.
    static var displayOrder: [BadgeID] {
        [.firstLight, .cumulus, .stratus, .cirrus, .sunburst,
         .clearSky, .boundless, .earlyBird, .wanderer, .comeback]
    }
}

// MARK: - Badge engine

/// Stateless evaluator. Pass the current progress snapshot (with counters already
/// incremented for this verification) and the verification timestamp; receive the
/// list of badges newly earned. Already-unlocked badges are never returned.
struct BadgeEngine {

    /// Evaluates all badge conditions given the already-updated `progress`.
    /// - Parameters:
    ///   - progress: The `UserProgress` value **after** the verification counters
    ///     have been incremented (e.g. `totalVerifications == 1` on first ever).
    ///   - verificationTime: The wall-clock time of the verification (for Early Bird).
    /// - Returns: Badges earned for the first time during this verification.
    static func evaluate(progress: UserProgress, verificationTime: Date) -> [BadgeID] {
        var earned: [BadgeID] = []
        let already = progress.unlockedBadges

        // First Light — very first verification ever
        if !already.contains(.firstLight) && progress.totalVerifications == 1 {
            earned.append(.firstLight)
        }

        // Streak-based badges
        let streakThresholds: [(BadgeID, Int)] = [
            (.cumulus,  3),
            (.stratus,  7),
            (.cirrus,   14),
            (.sunburst, 30),
            (.clearSky, 60),
            (.boundless, 100)
        ]
        for (badge, threshold) in streakThresholds {
            if !already.contains(badge) && progress.currentStreak >= threshold {
                earned.append(badge)
            }
        }

        // Early Bird — verified before 8 AM local time
        if !already.contains(.earlyBird) {
            let hour = Calendar.current.component(.hour, from: verificationTime)
            if hour < 8 { earned.append(.earlyBird) }
        }

        // Wanderer — at least 5 distinct rounded locations
        if !already.contains(.wanderer) && progress.verificationLocations.count >= 5 {
            earned.append(.wanderer)
        }

        // Comeback — had an emergency unlock, then earned 7 clean days afterward
        if !already.contains(.comeback)
            && progress.hadEmergencyUnlock
            && progress.streakAfterFirstEmergency >= 7 {
            earned.append(.comeback)
        }

        return earned
    }
}
