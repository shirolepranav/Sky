// VerificationIntroView.swift
// S-VER-01 — Briefs the user before recording begins.
// Sky_App_Workflow.md §Part 2 S-VER-01.

import SwiftUI

struct VerificationIntroView: View {
    var onPrimary: () -> Void
    var onClose: () -> Void

    private struct BulletItem {
        let icon: String
        let text: String
    }

    private let bullets: [BulletItem] = [
        BulletItem(icon: "figure.walk",
                   text: "You'll record a 30-second video while walking."),
        BulletItem(icon: "sun.max",
                   text: "Point at the sky for a few seconds when Sky asks."),
        BulletItem(icon: "lock",
                   text: "Everything stays on your phone."),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            SkyColor.surface.ignoresSafeArea()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SkyColor.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, SkySpacing.s5)
            .padding(.leading, SkySpacing.s4)
            .accessibilityLabel("Close")

            // Main content
            VStack(spacing: 0) {
                Spacer(minLength: SkySpacing.s10)

                NimbusView(state: .fluffyWhite, size: 200)
                    .padding(.bottom, SkySpacing.s6)

                Text("Ready to head outside?")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)

                VStack(alignment: .leading, spacing: SkySpacing.s4) {
                    ForEach(bullets, id: \.icon) { bullet in
                        HStack(alignment: .top, spacing: SkySpacing.s3) {
                            Image(systemName: bullet.icon)
                                .font(.system(size: 17))
                                .foregroundColor(SkyColor.mossGreen)
                                .frame(width: 24)
                            Text(bullet.text)
                                .skyText(.body, color: SkyColor.inkSoft)
                        }
                    }
                }
                .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                SkyPrimaryButton("I'm outside", action: onPrimary)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.intro")
    }
}

#Preview("S-VER-01") {
    VerificationIntroView(onPrimary: {}, onClose: {})
}

#Preview("S-VER-01 dark") {
    VerificationIntroView(onPrimary: {}, onClose: {})
        .preferredColorScheme(.dark)
}
