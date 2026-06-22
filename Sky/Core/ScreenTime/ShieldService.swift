// ShieldService.swift
// Named wrapper around ManagedSettingsStore shield operations so shield
// clearing is never duplicated inline. Called from VerificationSuccessView
// after a successful outdoor verification.
// Tech Spec §7.6, Roadmap Phase 10.

import ManagedSettings

enum ShieldService {

    /// Clears all active application and category shields, allowing the user's
    /// selected apps to open until the next midnight reset.
    static func unlockApps() {
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
