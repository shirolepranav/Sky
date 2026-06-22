// SkyShieldAction.swift
// Principal class for the ShieldAction extension target (Technical Spec §7.5).
// iOS routes shield button taps here.
//
// Phase 0 stub: the empty subclass inherits ShieldActionDelegate's defaults so
// the target builds. Real handling — opening sky://verify on the primary button
// and sky://emergency on the auxiliary button, then completionHandler(.close) —
// is implemented in Roadmap Phase 6.

import ManagedSettings
import ManagedSettingsUI

final class SkyShieldAction: ShieldActionDelegate {
    // TODO(Phase 6): override handle(action:for:completionHandler:) to open the
    // sky:// deep links and close the shield.
}
