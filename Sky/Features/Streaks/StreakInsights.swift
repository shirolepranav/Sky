// StreakInsights.swift
// Pure derivations over `UserProgress` for the Streaks tab (S-STREAK-01).
//
// Everything here is computed from data that already exists — `currentStreak`,
// `longestStreak`, `totalVerifications`, `lastVerificationDate`. Nothing new is
// persisted and the CloudKit schema is untouched. In particular the last-seven-
// days strip is derived from the streak window rather than a per-day log, which
// the app has never kept.
//
// Kept free of SwiftUI so it can be unit-tested directly (SkyTests/StreakInsightsTests).
// Sky_App_Workflow.md §Group C S-STREAK-01; Roadmap Phase 12.

import Foundation

enum StreakInsights {

    /// The streak lengths that earn a celebration and a badge.
    /// Single source of truth — `StreakManager.isMilestoneStreak(_:)` reads this.
    static let milestones: [Int] = [3, 7, 14, 30, 60, 100]

    // MARK: - Hero state

    /// Which headline the Streaks hero should show.
    enum HeroState: Equatable {
        /// Never verified — the streak has not started yet.
        case firstTime
        /// A live streak of one or more days.
        case active
        /// Has verified before, but the streak is currently at zero.
        case broken
    }

    static func heroState(_ progress: UserProgress) -> HeroState {
        if progress.currentStreak > 0 { return .active }
        return progress.totalVerifications > 0 ? .broken : .firstTime
    }

    // MARK: - Next milestone

    struct MilestoneProgress: Equatable {
        /// The streak length being worked toward, e.g. 14.
        let target: Int
        /// Days still to go.
        let daysRemaining: Int
        /// 0...1 progress from the previous milestone to `target`.
        let fraction: Double
        /// The badge earned at `target`.
        let badge: BadgeID?
    }

    /// The milestone the user is working toward, or nil once every milestone is passed.
    static func nextMilestone(after streak: Int) -> MilestoneProgress? {
        guard let target = milestones.first(where: { $0 > streak }) else { return nil }
        let previous = milestones.last(where: { $0 <= streak }) ?? 0
        let span = target - previous
        let fraction = span > 0 ? Double(streak - previous) / Double(span) : 0
        return MilestoneProgress(
            target: target,
            daysRemaining: target - streak,
            fraction: min(max(fraction, 0), 1),
            badge: badge(forMilestone: target)
        )
    }

    /// The streak badge awarded at a given milestone length.
    static func badge(forMilestone days: Int) -> BadgeID? {
        switch days {
        case 3:   return .cumulus
        case 7:   return .stratus
        case 14:  return .cirrus
        case 30:  return .sunburst
        case 60:  return .clearSky
        case 100: return .boundless
        default:  return nil
        }
    }

    // MARK: - Last seven days

    struct DayMark: Equatable, Identifiable {
        let date: Date
        /// True when this day falls inside the current streak window.
        let isVerified: Bool
        let isToday: Bool

        var id: Date { date }
    }

    /// The last seven calendar days, oldest first.
    ///
    /// A day counts as verified when it falls inside the current streak window —
    /// the `currentStreak` days ending at `lastVerificationDate`. That window is
    /// exactly what the streak means, so this is accurate for every day the
    /// streak covers without storing a day-by-day history. Days outside the
    /// window are days the streak does not cover (missed, or an emergency
    /// unlock), which is precisely what an unfilled dot should convey.
    static func lastSevenDays(progress: UserProgress,
                              now: Date = Date(),
                              calendar: Calendar = .current) -> [DayMark] {
        let today = calendar.startOfDay(for: now)

        // The inclusive [start, end] day range covered by the current streak.
        var window: (start: Date, end: Date)?
        if progress.currentStreak > 0,
           let last = progress.lastVerificationDate {
            let end = calendar.startOfDay(for: last)
            if let start = calendar.date(byAdding: .day,
                                         value: -(progress.currentStreak - 1),
                                         to: end) {
                window = (start, end)
            }
        }

        return (0..<7).compactMap { offset -> DayMark? in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }
            let verified: Bool
            if let window {
                verified = day >= window.start && day <= window.end
            } else {
                verified = false
            }
            return DayMark(date: day, isVerified: verified, isToday: day == today)
        }
    }

    /// Single-letter weekday initials for the strip, aligned to `lastSevenDays`.
    static func weekdayInitial(for date: Date, calendar: Calendar = .current) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}
