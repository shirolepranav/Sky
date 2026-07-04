// SubscriptionView.swift
// S-SET-07 · Subscription screen — shows the user's current tier and offers
// upgrade / manage / restore actions.
// Phase 14: standalone screen surfaced from the Settings tab placeholder.
// Phase 15 will embed it inside the full SettingsView.
// Sky_App_Workflow.md §Group C S-SET-07; Roadmap Phase 14.

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var storeKit: StoreKitService

    @State private var showPaywall = false
    @State private var restoreOutcome: RestoreOutcome? = nil
    @State private var showRestoreSheet = false

    var body: some View {
        NavigationStack {
            List {
                tierSection
                actionsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SkyColor.surface.ignoresSafeArea())
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environmentObject(storeKit)
        }
        .sheet(isPresented: $showRestoreSheet) {
            if let outcome = restoreOutcome {
                RestorePurchasesResultView(outcome: outcome) {
                    showRestoreSheet = false
                }
                .presentationDetents([.medium])
            }
        }
        .accessibilityIdentifier("subscription.root")
    }

    // MARK: - Tier section

    @ViewBuilder
    private var tierSection: some View {
        Section {
            SkyCard {
                VStack(alignment: .leading, spacing: SkySpacing.s3) {
                    tierHeader

                    Text(tierDescription)
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if !storeKit.isPro {
                        SkyPrimaryButton("Upgrade to Pro") {
                            showPaywall = true
                        }
                        .padding(.top, SkySpacing.s2)
                    }
                }
            }
            .padding(.vertical, SkySpacing.s2)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var tierHeader: some View {
        HStack(spacing: SkySpacing.s3) {
            Image(systemName: storeKit.isPro ? "crown.fill" : "person.circle")
                .foregroundStyle(storeKit.isPro ? SkyColor.sunYellow : SkyColor.inkMuted)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(tierTitle)
                    .skyText(.headline, color: SkyColor.ink)
                if let renewal = renewalLine {
                    Text(renewal)
                        .skyText(.caption, color: SkyColor.inkSoft)
                }
            }

            Spacer()
        }
    }

    private var tierTitle: String {
        switch storeKit.currentTier {
        case .monthly:       return "Sky Pro · Monthly"
        case .annual:        return "Sky Pro · Annual"
        case .lifetime:      return "Sky Pro · Lifetime"
        case .founderLifetime: return "Sky Pro · Founder's Lifetime"
        case nil:            return "Sky Free"
        }
    }

    private var tierDescription: String {
        switch storeKit.currentTier {
        case .monthly(let renewal):
            return renewal.map { "Renews \(formatted($0))." } ?? "Monthly subscription."
        case .annual(let renewal, let isTrial, let trialEnd):
            if isTrial, let end = trialEnd {
                return "Free trial ends \(formatted(end)). Renews yearly afterward."
            }
            return renewal.map { "Renews \(formatted($0))." } ?? "Annual subscription."
        case .lifetime:
            return "Lifetime access. Thanks for going all in."
        case .founderLifetime:
            return "Founder's Lifetime access. You were one of the first 500."
        case nil:
            return "Up to 2 apps, combined limits only."
        }
    }

    private var renewalLine: String? {
        switch storeKit.currentTier {
        case .annual(_, isTrial: true, _): return "Free trial active"
        default: return nil
        }
    }

    // MARK: - Actions section

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            if case .monthly = storeKit.currentTier {
                manageRow
            } else if case .annual = storeKit.currentTier {
                manageRow
            }

            Button("Restore purchases") {
                Task { await handleRestore() }
            }
            .foregroundStyle(SkyColor.mossGreen)
            .accessibilityIdentifier("subscription.restore")
        }
    }

    private var manageRow: some View {
        Link("Manage in App Store", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            .foregroundStyle(SkyColor.mossGreen)
            .accessibilityIdentifier("subscription.manage")
    }

    // MARK: - Helpers

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func handleRestore() async {
        let outcome = await storeKit.restorePurchases()
        restoreOutcome = outcome
        showRestoreSheet = true
    }
}

#Preview("S-SET-07 Free") {
    SubscriptionView()
        .environmentObject(StoreKitService())
}
