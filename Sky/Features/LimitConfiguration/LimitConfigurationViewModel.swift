// LimitConfigurationViewModel.swift
// State and persistence for the lock-time screen (S-CFG-03; DAILY_LOCK_PLAN.md
// Phase D). Sky_App_Workflow.md §S-CFG-03. Sky_Technical_Spec.md §6.1.
//
// Reads and writes `lockTimeMinutes` and `lockWeekdays` from SharedDefaults. The
// injectable `store` keeps this testable with an isolated UserDefaults suite.
//
// Choosing lock days (anything other than every day) is the Pro feature;
// `showsLockDaysProGate` signals the view to present S-PAY-05.

import SwiftUI

@MainActor
final class LimitConfigurationViewModel: ObservableObject {

    // MARK: Published state

    @Published var lockTimeMinutes: Int
    @Published private(set) var lockWeekdays: Set<Int>

    /// Set when a free user tries to change lock days. View presents S-PAY-05.
    @Published var showsLockDaysProGate = false

    private let store: SharedDefaults

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        self.lockTimeMinutes = store.lockTimeMinutes
        self.lockWeekdays = store.lockWeekdays
    }

    // MARK: Options

    /// Every half hour from 5 AM to the latest the schedule allows.
    static let lockTimeOptions: [Int] = Array(
        stride(from: 5 * 60, through: DeviceActivityService.latestLockTimeMinutes, by: 30)
    )

    /// Calendar weekdays (1 = Sunday) in the user's locale order.
    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    // MARK: Lock days (Pro)

    /// Flips one weekday on or off. Free users get the Pro gate instead; nobody can
    /// switch off the last remaining day (that's what Pause is for).
    func toggleWeekday(_ weekday: Int, isPro: Bool) {
        guard isPro else {
            showsLockDaysProGate = true
            return
        }
        if lockWeekdays.contains(weekday) {
            guard lockWeekdays.count > 1 else { return }
            lockWeekdays.remove(weekday)
        } else {
            lockWeekdays.insert(weekday)
        }
    }

    // MARK: Persistence

    func save() {
        store.lockTimeMinutes = min(max(lockTimeMinutes, 0), DeviceActivityService.latestLockTimeMinutes)
        store.lockWeekdays = lockWeekdays
    }
}
