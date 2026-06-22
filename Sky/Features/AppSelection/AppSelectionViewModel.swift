// AppSelectionViewModel.swift
// State for the app-selection root (Sky_App_Workflow.md §S-CFG-01). Holds the
// working `FamilyActivitySelection`, derives the count/empty state shown on the
// summary card, and persists to the App Group via SharedDefaults so the
// monitoring extension can read it (Phase 5+).
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

    private let store: SharedDefaults

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        self.selection = store.selection ?? FamilyActivitySelection()
        self.needsRedo = store.selectionNeedsRedo
    }

    /// Number of selected apps + categories (no names, just the tally).
    var count: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var isEmpty: Bool { count == 0 }

    /// Continue is allowed once at least one app/category is chosen and the
    /// stored selection is valid.
    var canContinue: Bool { !isEmpty && !needsRedo }

    /// Persist the current selection after the picker dismisses.
    func persistSelection() {
        store.selection = selection
        needsRedo = false
        // TODO(Phase 14): enforce free 2-app cap via StoreKitService.isPro + toast → S-PAY-01
    }
}
