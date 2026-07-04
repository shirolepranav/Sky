// AppSelectionViewModel.swift
// State for the app-selection root (Sky_App_Workflow.md §S-CFG-01). Holds the
// working `FamilyActivitySelection`, derives the count/empty state shown on the
// summary card, and persists to the App Group via SharedDefaults so the
// monitoring extension can read it (Phase 5+).
//
// Phase 14: enforces the free-tier 2-app cap. `needsUpgrade` is set when a free
// user picks more than 2 apps; the view observes it to show S-PAY-05.
//
// Sky never sees app names — only opaque tokens (Tech Spec §7.2). The count is
// the only thing surfaced in text.

import Foundation
import FamilyControls

@MainActor
final class AppSelectionViewModel: ObservableObject {
    /// Bound to `FamilyActivityPicker` (S-CFG-02); mutated by Apple's picker.
    @Published var selection: FamilyActivitySelection

    /// True when stored selection Data failed to decode (stale tokens after an
    /// iOS update) — drives the "needs redoing" warning on S-CFG-01.
    @Published private(set) var needsRedo: Bool

    /// Set when a free user picks more than 2 apps. View shows S-PAY-05 gate.
    /// Cleared when the gate is dismissed or the selection is within cap.
    @Published var needsUpgrade: Bool = false

    private let store: SharedDefaults

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        self.selection = store.selection ?? FamilyActivitySelection()
        self.needsRedo = store.selectionNeedsRedo
    }

    // MARK: - Free-tier cap (Phase 14)

    /// Pure function: free users may manage at most 2 apps/categories combined.
    static func isOverFreeLimit(count: Int, isPro: Bool) -> Bool {
        !isPro && count > 2
    }

    /// Number of selected apps + categories (no names, just the tally).
    var count: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var appCount: Int { selection.applicationTokens.count }
    var categoryCount: Int { selection.categoryTokens.count }

    var isEmpty: Bool { count == 0 }

    /// A human-readable tally that distinguishes apps from whole categories — a
    /// category isn't an app, so "1 app selected" would be misleading. Sky still
    /// never sees names, only counts (Tech Spec §7.2).
    var summaryText: String {
        switch (appCount, categoryCount) {
        case (0, 0):
            return "No apps selected yet."
        case (let apps, 0):
            return "\(appsPhrase(apps)) selected"
        case (0, let cats):
            return "\(categoriesPhrase(cats)) selected"
        case (let apps, let cats):
            return "\(appsPhrase(apps)) and \(categoriesPhrase(cats)) selected"
        }
    }

    private func appsPhrase(_ n: Int) -> String { "\(n) app\(n == 1 ? "" : "s")" }
    private func categoriesPhrase(_ n: Int) -> String { "\(n) categor\(n == 1 ? "y" : "ies")" }

    /// Continue is allowed once at least one app/category is chosen and the
    /// stored selection is valid.
    var canContinue: Bool { !isEmpty && !needsRedo }

    /// Persist the current selection after the picker dismisses.
    /// - Parameter isPro: Pass `storeKit.isPro` from the calling view.
    func persistSelection(isPro: Bool = false) {
        if Self.isOverFreeLimit(count: count, isPro: isPro) {
            needsUpgrade = true
            return
        }
        store.selection = selection
        needsRedo = false
        needsUpgrade = false
    }
}
