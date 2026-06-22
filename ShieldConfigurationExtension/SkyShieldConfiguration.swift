// SkyShieldConfiguration.swift
// Principal class for the ShieldConfiguration extension target
// (Technical Spec §7.5). iOS asks this data source how to render the shield when
// the user taps a blocked app.
//
// Phase 0 stub: the empty subclass inherits ShieldConfigurationDataSource's
// default configuration so the target builds. The branded Sky shield — warm
// cream background, Nimbus image, "Time's up" copy, "Go outside to unlock" /
// "I can't go outside right now" buttons — is implemented in Roadmap Phase 6.

import ManagedSettings
import ManagedSettingsUI

final class SkyShieldConfiguration: ShieldConfigurationDataSource {
    // TODO(Phase 6): override configuration(shielding:) and
    // configuration(shielding:in:) to return the branded ShieldConfiguration.
}
