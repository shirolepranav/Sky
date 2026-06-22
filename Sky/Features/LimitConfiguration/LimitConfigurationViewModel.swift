// LimitConfigurationViewModel.swift
// State and persistence for the daily-limit configuration screen (S-CFG-03/04/05).
// Sky_App_Workflow.md §S-CFG-03. Sky_Technical_Spec.md §6.1.
//
// Reads and writes `limitMode`, `combinedLimitSeconds`, and `perAppLimitsData`
// from SharedDefaults. The injectable `store` parameter keeps this testable with
// an isolated UserDefaults suite — the same pattern used in AppSelectionViewModel.

import SwiftUI
import FamilyControls
import ManagedSettings

@MainActor
final class LimitConfigurationViewModel: ObservableObject {

    enum LimitMode: String {
        case combined = "combined"
        case perApp   = "perApp"
    }

    // MARK: Published state

    @Published var limitMode: LimitMode
    @Published var combinedLimitSeconds: Int
    /// Per-app budgets keyed by token. Access via `minutesBinding(for:)` which
    /// applies 60 m defaults and clamps to the 15–240 m range.
    @Published var perAppMinutes: [ApplicationToken: Int]

    // MARK: Storage

    private let store: SharedDefaults

    // MARK: Init

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        self.limitMode      = LimitMode(rawValue: store.limitMode) ?? .combined
        self.combinedLimitSeconds = store.combinedLimitSeconds
        self.perAppMinutes  = Self.decodePerAppLimits(from: store.perAppLimitsData)
    }

    // MARK: Derived

    /// App tokens from the persisted selection, in a stable order. Computed
    /// lazily so it always reflects the latest SharedDefaults selection even when
    /// this ViewModel was created before the user completed app selection.
    var appTokens: [ApplicationToken] {
        Array(store.selection?.applicationTokens ?? [])
            .sorted { $0.hashValue < $1.hashValue }
    }

    // MARK: Persistence

    func save() {
        // Seed 60 m defaults for any tokens not yet explicitly changed.
        for token in appTokens where perAppMinutes[token] == nil {
            perAppMinutes[token] = 60
        }
        store.limitMode           = limitMode.rawValue
        store.combinedLimitSeconds = combinedLimitSeconds
        store.perAppLimitsData    = encodePerAppLimits()
    }

    // MARK: Stepper binding

    /// A `Binding<Int>` for the per-app stepper that:
    ///   - returns 60 m if no value has been set yet (first entry)
    ///   - clamps writes to 15–240 m (15 min – 4 hours, 15 min steps)
    ///   - fires a light haptic on each value change
    func minutesBinding(for token: ApplicationToken) -> Binding<Int> {
        Binding(
            get: { self.perAppMinutes[token, default: 60] },
            set: { newValue in
                let clamped = min(max(newValue, 15), 240)
                self.perAppMinutes[token] = clamped
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        )
    }

    /// Clamps a raw minutes value into the valid 15–240 range.
    /// Exposed for unit-testing the clamping logic independently of ApplicationToken.
    func clampedMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 15), 240)
    }

    // MARK: Codable helpers

    struct TokenLimitEntry: Codable {
        let token: ApplicationToken
        var minutes: Int
    }

    private static func decodePerAppLimits(from data: Data?) -> [ApplicationToken: Int] {
        guard let data,
              let entries = try? JSONDecoder().decode([TokenLimitEntry].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.token, $0.minutes) })
    }

    private func encodePerAppLimits() -> Data? {
        let entries = perAppMinutes.map { TokenLimitEntry(token: $0.key, minutes: $0.value) }
        return try? JSONEncoder().encode(entries)
    }
}
