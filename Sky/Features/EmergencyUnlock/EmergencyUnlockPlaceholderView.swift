// EmergencyUnlockPlaceholderView.swift
// Destination for the sky://emergency deep link (S-SHIELD-03 → S-EMG-01).
//
// Phase 6 stub: shows Nimbus (rainy state) and holding copy so the deep-link
// round-trip is testable end-to-end. Phase 13 replaces this with the real flow:
// paste-blocked typed reason, 5-second forced delay, streak-breaking logic,
// and on-device-only reason storage.

import SwiftUI

struct EmergencyUnlockPlaceholderView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s8) {
                NimbusView(state: .rainy, size: 160)
                    .padding(.bottom, SkySpacing.s2)

                Text("Emergency unlock")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("We'll need to know why you can't go outside right now.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                SkySecondaryButton("Cancel") { onDismiss() }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
            .padding(.top, SkySpacing.s10)
        }
        .accessibilityIdentifier("emergency.placeholder")
    }
}

#Preview("Emergency unlock placeholder") {
    EmergencyUnlockPlaceholderView(onDismiss: {})
}
