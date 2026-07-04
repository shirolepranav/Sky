// RestorePurchasesResultView.swift
// S-PAY-03 · Restore Purchases Result — communicates success, nothing found,
// or a network error after a restore attempt.
// Sky_App_Workflow.md §Group G S-PAY-03; Roadmap Phase 14.

import SwiftUI

struct RestorePurchasesResultView: View {
    let outcome: RestoreOutcome
    let onDone: () -> Void

    private var icon: String {
        switch outcome {
        case .restored:      return "checkmark.circle.fill"
        case .nothingFound:  return "archivebox"
        case .networkError:  return "wifi.slash"
        }
    }

    private var iconColor: Color {
        switch outcome {
        case .restored:      return SkyColor.mossGreen
        case .nothingFound:  return SkyColor.inkMuted
        case .networkError:  return SkyColor.coralStreak
        }
    }

    private var title: String {
        switch outcome {
        case .restored:      return "You're all set."
        case .nothingFound:  return "No purchases found."
        case .networkError:  return "Couldn't reach the App Store."
        }
    }

    private var body_: String {
        switch outcome {
        case .restored:
            return "Your Sky Pro purchase has been restored on this device."
        case .nothingFound:
            return "If you bought Sky Pro on this Apple ID, make sure you're signed in to the same account."
        case .networkError:
            return "Check your connection and try again."
        }
    }

    var body: some View {
        VStack(spacing: SkySpacing.s6) {
            Capsule()
                .fill(SkyColor.inkDisabled)
                .frame(width: 36, height: 4)
                .padding(.top, SkySpacing.s3)

            Spacer(minLength: SkySpacing.s4)

            Image(systemName: icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(iconColor)

            VStack(spacing: SkySpacing.s3) {
                Text(title)
                    .skyText(.titleM)
                    .multilineTextAlignment(.center)

                Text(body_)
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SkyLayout.screenMargin)

            Spacer(minLength: SkySpacing.s4)

            SkyPrimaryButton("Done", action: onDone)
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkyLayout.bottomSafeArea)
        }
        .frame(maxWidth: .infinity)
        .background(SkyColor.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body_)")
    }
}

#Preview("S-PAY-03 Restored") {
    RestorePurchasesResultView(outcome: .restored, onDone: {})
        .presentationDetents([.medium])
}

#Preview("S-PAY-03 Nothing found") {
    RestorePurchasesResultView(outcome: .nothingFound, onDone: {})
        .presentationDetents([.medium])
}

#Preview("S-PAY-03 Network error") {
    RestorePurchasesResultView(outcome: .networkError, onDone: {})
        .presentationDetents([.medium])
}
