// MascotStateManager.swift
// Derives and publishes the current mascot state from SharedDefaults flags.
// Implements the state machine from Sky_App_Workflow.md §0.3.
//
// Phase 11 — Roadmap Phase 11.

import Foundation
import Combine

/// Observes app-state flags (SharedDefaults) and publishes the correct `MascotState`
/// so every view that shows Nimbus stays in sync without extra coordination.
///
/// State derivation (priority order):
///   1. `didEmergencyUnlockToday` → `.rainy`
///   2. `didVerifyToday`          → `.sunny`
///   3. `isCurrentlyBlocked`      → `.cloudyGrey`
///   4. else                      → `.fluffyWhite`
///
/// The `.rainbow` state is transient (5 s, in-flow during S-VER-06 and S-CEL-02)
/// and is never persisted — it's driven by VerificationSuccessView / MilestoneOverlayView.
@MainActor
final class MascotStateManager: ObservableObject {
    @Published private(set) var state: MascotState = .fluffyWhite

    private let store: SharedDefaults

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        refreshState()
    }

    // MARK: - Public API

    /// Re-derive state from SharedDefaults. Call on every foreground transition
    /// and after any event that changes the underlying flags.
    func refreshState() {
        state = derivedState
    }

    /// Called after a successful verification once the success screen has written
    /// `didVerifyToday = true` to SharedDefaults.
    func handleVerificationSuccess() {
        refreshState()
    }

    /// Called after an emergency unlock once `didEmergencyUnlockToday = true`
    /// has been written to SharedDefaults.
    func handleEmergencyUnlock() {
        refreshState()
    }

    /// Called when the midnight reset clears today's flags.
    func handleMidnightReset() {
        refreshState()
    }

    // MARK: - Private

    private var derivedState: MascotState {
        if store.didEmergencyUnlockToday { return .rainy }
        if store.didVerifyToday          { return .sunny  }
        if store.isCurrentlyBlocked      { return .cloudyGrey }
        return .fluffyWhite
    }

    #if DEBUG
    /// Debug-menu (S-SET-09) override — force any mascot state for visual QA.
    func debugSetState(_ newState: MascotState) {
        state = newState
    }
    #endif
}
