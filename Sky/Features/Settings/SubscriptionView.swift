// SubscriptionView.swift
// S-SET-07 · Sky Pro screen — shows whether the user owns Sky Pro and offers
// upgrade / restore. Sky Pro is a single one-time purchase, so there is no
// renewal date to show and nothing to "manage" in the App Store.
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
            .navigationTitle("Sky Pro")
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

            Text(tierTitle)
                .skyText(.headline, color: SkyColor.ink)

            Spacer()
        }
    }

    private var tierTitle: String {
        storeKit.isPro ? "Sky Pro" : "Sky Free"
    }

    private var tierDescription: String {
        storeKit.isPro
        ? "Lifetime access. Thanks for going all in."
        : "Up to 2 apps, combined limits only."
    }

    // MARK: - Actions section

    private var actionsSection: some View {
        Section {
            Button("Restore purchases") {
                Task { await handleRestore() }
            }
            .foregroundStyle(SkyColor.mossGreen)
            .accessibilityIdentifier("subscription.restore")
        } footer: {
            Text("Sky Pro is a one-time purchase, not a subscription. Restoring re-applies it on a new device.")
        }
    }

    // MARK: - Helpers

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
