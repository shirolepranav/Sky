// ShieldService.swift
// Named wrapper around ManagedSettingsStore shield operations so shield
// clearing is never duplicated inline. Called from VerificationSuccessView
// after a successful outdoor verification.
// Tech Spec §7.6, Roadmap Phase 10.
//
// The shield is *applied* by SkyDeviceActivityMonitor, in another process, on a
// callback that fires once per event per day. That makes the block a one-shot:
// anything that drops the shield — an OS quirk, an invalidated token, a bug like
// the late midnight reset that MidnightResetRecovery used to perform — left the
// apps open until the next real midnight, because nothing ever put it back.
//
// `reconcile` closes that. Today's persisted state is the authority on whether
// apps should be blocked; the ManagedSettings store is just a cache of it, and
// every foreground repairs the cache. Clearing stays exclusive to `unlockApps`,
// so reconciliation can only ever make the app *more* strict.

import Foundation
import FamilyControls
import ManagedSettings

enum ShieldService {

    /// Clears all active application and category shields, allowing the user's
    /// selected apps to open until the next session ends (or, for an emergency
    /// unlock or a pause, until the midnight reset).
    ///
    /// The four legitimate callers are a passed verification, a completed
    /// emergency unlock, a Pro pause, and the midnight reset. Nothing else may
    /// call this — `source` is recorded so a fifth caller is visible on-device.
    static func unlockApps(
        source: ShieldAudit.Source,
        store: SharedDefaults = SharedDefaults()
    ) {
        let managed = ManagedSettingsStore()
        managed.shield.applications = nil
        managed.shield.applicationCategories = nil
        store.shieldedAppTokens = nil
        ShieldAudit.record(.cleared, source: source, appCount: 0)
    }

    /// Re-applies the shield to exactly `tokens` (plus `categories`, which only
    /// combined mode uses). Mirrors the write in
    /// `SkyDeviceActivityMonitor.eventDidReachThreshold`.
    static func applyShield(
        tokens: Set<ApplicationToken>,
        categories: Set<ActivityCategoryToken>,
        source: ShieldAudit.Source,
        store: SharedDefaults = SharedDefaults()
    ) {
        let managed = ManagedSettingsStore()
        managed.shield.applications = tokens.isEmpty ? nil : tokens
        managed.shield.applicationCategories = categories.isEmpty
            ? nil
            : .specific(categories)
        store.shieldedAppTokens = try? JSONEncoder().encode(tokens)
        ShieldAudit.record(.applied, source: source, appCount: tokens.count)
    }

    /// Restores the shield when today's state says the user should be blocked but
    /// the ManagedSettings store disagrees.
    ///
    /// Call on every foreground and whenever the verification flow is left
    /// without a pass — backing out of verification must not open the apps.
    ///
    /// Never clears: a `false` here means "leave it alone", not "unshield". If the
    /// day's state says unblocked, whatever unblocked it already cleared the store.
    ///
    /// - Returns: true if a shield was (re-)applied.
    @discardableResult
    static func reconcile(store: SharedDefaults = SharedDefaults()) -> Bool {
        guard shouldBeBlocked(store: store) else { return false }

        let tokens = tokensToRestore(store: store)
        // Per-app mode with no recorded token set means we cannot tell which app
        // ran out of budget. Shielding the whole selection would lock apps that
        // are still well inside their own limit, which is worse than waiting for
        // the next threshold event — so leave it to the extension.
        guard !tokens.isEmpty else { return false }

        let managed = ManagedSettingsStore()
        let categories = categoriesToRestore(store: store)
        let alreadyShielded = (managed.shield.applications ?? []).isSuperset(of: tokens)
        guard !alreadyShielded else { return false }

        applyShield(tokens: tokens, categories: categories, source: .reconcile, store: store)
        return true
    }

    // MARK: - Decision (internal so unit tests can drive it without ManagedSettings)

    /// Today's state, in one place. Mirrors the precedence the monitor extension
    /// applies: a pause outranks everything, then the emergency unlock.
    ///
    /// ⚠️ `didVerifyToday` is deliberately **not** consulted. It used to be, and
    /// that single line was what made a passed verification open the apps until
    /// midnight — one 30-second video at 9am bought fifteen unmetered hours, which
    /// is the opposite of what Sky is for. A verification now clears
    /// `isCurrentlyBlocked` and buys one session; the next rung of the ladder sets
    /// the flag again once that session's usage is spent
    /// (`SkyDeviceActivityMonitor`). `didVerifyToday` still drives the streak, the
    /// mascot, and today's copy — just not the shield.
    ///
    /// An emergency unlock does still cover the whole day. It is friction-gated and
    /// streak-costing already; making someone retype a reason every two hours
    /// because they genuinely cannot get outside is punishment, not friction.
    static func shouldBeBlocked(store: SharedDefaults) -> Bool {
        guard store.isCurrentlyBlocked else { return false }
        guard !store.isPaused else { return false }
        guard !store.didEmergencyUnlockToday else { return false }
        return true
    }

    /// The tokens the monitor extension actually shielded, falling back to the
    /// whole selection in combined mode (where "the budget" covers all of it).
    static func tokensToRestore(store: SharedDefaults) -> Set<ApplicationToken> {
        if let data = store.shieldedAppTokens,
           let tokens = try? JSONDecoder().decode(Set<ApplicationToken>.self, from: data),
           !tokens.isEmpty {
            return tokens
        }
        guard store.limitMode != "perApp" else { return [] }
        return store.selection?.applicationTokens ?? []
    }

    /// Categories carry no per-app budget, so only combined mode shields them.
    static func categoriesToRestore(store: SharedDefaults) -> Set<ActivityCategoryToken> {
        guard store.limitMode != "perApp" else { return [] }
        return store.selection?.categoryTokens ?? []
    }
}
