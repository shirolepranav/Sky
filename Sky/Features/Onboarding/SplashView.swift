// SplashView.swift
// Splash / first-launch routing frame — Sky_App_Workflow.md §S-ONB-01.
// A near-instant frame shown while the coordinator resolves the cold-launch
// route. Centered Nimbus + "Sky" wordmark; a subtle pulse appears only if
// routing takes longer than ~300ms (e.g. slow CloudKit fetch in later phases).

import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            SkyColor.warmCream.ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                NimbusView(state: .fluffyWhite, size: 160)
                    .scaleEffect(pulse ? 1.04 : 1.0)

                // Wordmark. `.display` (40pt heavy rounded) is the largest type
                // token; DESIGN_SYSTEM tokens are authoritative over the catalog's
                // illustrative 56pt note.
                Text(AppBranding.appName)
                    .skyText(.display, color: SkyColor.primarySkyDeep)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(AppBranding.appName) is starting")
        .onAppear {
            guard !reduceMotion else { return }
            // Begin the gentle pulse only after a short delay, so it shows only
            // when routing is slow (it's invisible on the common <300ms path).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

#Preview("S-ONB-01 Splash") {
    SplashView()
}
