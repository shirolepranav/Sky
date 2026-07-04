// PaywallView.swift
// S-PAY-01 (+ S-PAY-02 inline variant) — Full paywall presented as a
// .fullScreenCover. Annual tier highlighted as default "Best Value".
// One-shot post-verification upsell and all Pro-gate entry points land here.
// Sky_App_Workflow.md §Group G S-PAY-01/S-PAY-02; Roadmap Phase 14.

import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    let onDismiss: () -> Void

    @State private var purchasingID: String? = nil
    @State private var loadError: Bool = false
    @State private var restoreOutcome: RestoreOutcome? = nil
    @State private var showRestoreSheet: Bool = false
    @State private var showTrialConfirm: Bool = false
    @State private var trialEndDate: Date? = nil

    private var isLoading: Bool { storeKit.products.isEmpty && !loadError }
    private var alreadyPro: Bool { storeKit.isPro }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SkyColor.surface.ignoresSafeArea()

            if alreadyPro {
                alreadyProScreen
            } else {
                scrollContent
            }

            // Close button (always visible)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(SkyColor.inkMuted)
                    .background(SkyColor.surface.opacity(0.8), in: Circle())
            }
            .padding([.top, .trailing], SkySpacing.s5)
            .accessibilityLabel("Close")
        }
        .sheet(isPresented: $showRestoreSheet) {
            if let outcome = restoreOutcome {
                RestorePurchasesResultView(outcome: outcome) {
                    showRestoreSheet = false
                    if outcome == .restored { onDismiss() }
                }
                .presentationDetents([.medium])
            }
        }
        .fullScreenCover(isPresented: $showTrialConfirm) {
            if let end = trialEndDate {
                TrialStartConfirmationView(trialEndDate: end) {
                    showTrialConfirm = false
                    onDismiss()
                }
            }
        }
        .task {
            if storeKit.products.isEmpty {
                do {
                    try await storeKit.loadProducts()
                } catch {
                    loadError = true
                }
            }
        }
        .accessibilityIdentifier("paywall")
    }

    // MARK: - Scrollable content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SkySpacing.s8) {
                heroSection

                if loadError {
                    errorSection
                } else {
                    tierCardsSection

                    if storeKit.founderSeatsRemaining > 0 || isLoading {
                        founderSection
                    }

                    comparisonSection
                }

                restoreSection
                legalFooter

                Spacer(minLength: SkyLayout.bottomSafeArea)
            }
            .padding(.horizontal, SkyLayout.screenMargin)
            .padding(.top, SkySpacing.s10)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: SkySpacing.s4) {
            NimbusView(state: .rainbow, size: 120)

            Text("Sky Pro")
                .skyText(.titleXL)
                .multilineTextAlignment(.center)

            Text("Go further than the free tier.")
                .skyText(.body, color: SkyColor.inkSoft)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: SkySpacing.s3) {
                FeatureBullet(icon: "infinity", text: "Unlimited apps.")
                FeatureBullet(icon: "chart.bar.fill", text: "Per-app limits.")
                FeatureBullet(icon: "star.fill", text: "Weekly insights & all badges.")
            }
            .padding(.top, SkySpacing.s2)
        }
    }

    // MARK: - Tier cards

    private var tierCardsSection: some View {
        HStack(alignment: .top, spacing: SkySpacing.s3) {
            TierCardView(
                product: storeKit.product(for: AppBranding.monthlyProductID),
                tierName: "Monthly",
                isHighlighted: false,
                isLoading: isLoading,
                action: { handlePurchase(id: AppBranding.monthlyProductID) }
            )

            TierCardView(
                product: storeKit.product(for: AppBranding.annualProductID),
                tierName: "Annual",
                isHighlighted: true,
                ribbonText: "Best Value",
                badgeText: "7-day free trial",
                isLoading: isLoading,
                action: { handlePurchase(id: AppBranding.annualProductID) }
            )

            TierCardView(
                product: storeKit.product(for: AppBranding.lifetimeProductID),
                tierName: "Lifetime",
                isHighlighted: false,
                isLoading: isLoading,
                action: { handlePurchase(id: AppBranding.lifetimeProductID) }
            )
        }
        .disabled(purchasingID != nil)
    }

    // MARK: - Founder card

    private var founderSection: some View {
        FounderCardView(
            product: storeKit.product(for: AppBranding.founderLifetimeProductID),
            seatsRemaining: storeKit.founderSeatsRemaining,
            isLoading: isLoading,
            action: { handlePurchase(id: AppBranding.founderLifetimeProductID) }
        )
        .disabled(purchasingID != nil)
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        SkyCard {
            VStack(spacing: 0) {
                ComparisonRow(
                    feature: "Apps you can manage",
                    free: "2 apps",
                    pro: "Unlimited",
                    isLast: false
                )
                ComparisonRow(
                    feature: "Daily limits",
                    free: "Combined",
                    pro: "Per-app ✓",
                    isLast: false
                )
                ComparisonRow(
                    feature: "Badges & insights",
                    free: "3 of 10",
                    pro: "All 10 ✓",
                    isLast: true
                )
            }
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button("Restore purchases") {
            Task { await handleRestore() }
        }
        .skyText(.bodyS, color: SkyColor.inkSoft)
        .accessibilityIdentifier("paywall.restore")
    }

    // MARK: - Legal footer

    private var legalFooter: some View {
        Text("Subscriptions auto-renew. Cancel anytime in App Store settings.")
            .skyText(.caption, color: SkyColor.inkMuted)
            .multilineTextAlignment(.center)
    }

    // MARK: - Error

    private var errorSection: some View {
        SkyCard {
            VStack(spacing: SkySpacing.s4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(SkyColor.inkMuted)

                Text("Couldn't load prices.")
                    .skyText(.headline)
                    .multilineTextAlignment(.center)

                SkySecondaryButton("Try again") {
                    loadError = false
                    Task {
                        do { try await storeKit.loadProducts() }
                        catch { loadError = true }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Already Pro

    private var alreadyProScreen: some View {
        VStack(spacing: SkySpacing.s6) {
            Spacer()

            NimbusView(state: .sunny, size: 160)

            VStack(spacing: SkySpacing.s3) {
                Text("You're already on Pro.")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("Thanks for supporting Sky.")
                    .skyText(.body, color: SkyColor.inkSoft)
            }

            if case .monthly = storeKit.currentTier {
                manageSubscriptionLink
            } else if case .annual = storeKit.currentTier {
                manageSubscriptionLink
            }

            Spacer()

            SkyPrimaryButton("Done", action: onDismiss)
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
        }
        .padding(.top, SkySpacing.s10)
        .accessibilityIdentifier("paywall.alreadyPro")
    }

    private var manageSubscriptionLink: some View {
        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
            Text("Manage subscription")
                .skyText(.label, color: SkyColor.mossGreen)
        }
    }

    // MARK: - Actions

    private func handlePurchase(id: String) {
        guard let product = storeKit.product(for: id) else { return }
        purchasingID = id
        Task {
            let outcome = await storeKit.purchase(product)
            purchasingID = nil

            switch outcome {
            case .success(let tier):
                if id == AppBranding.founderLifetimeProductID {
                    storeKit.decrementFounderSeats()
                }
                if case .annual(_, isTrial: true, let trialEnd) = tier, let end = trialEnd {
                    trialEndDate = end
                    showTrialConfirm = true
                } else {
                    onDismiss()
                }
            case .userCancelled, .pending:
                break
            case .failed:
                break
            }
        }
    }

    private func handleRestore() async {
        let outcome = await storeKit.restorePurchases()
        restoreOutcome = outcome
        showRestoreSheet = true
    }
}

// MARK: - Sub-views

private struct FeatureBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: SkySpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SkyColor.mossGreen)
                .frame(width: 20)
            Text(text)
                .skyText(.body, color: SkyColor.ink)
        }
    }
}

private struct ComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .skyText(.bodyS, color: SkyColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(free)
                    .skyText(.label, color: SkyColor.inkMuted)
                    .frame(width: 80, alignment: .center)
                Text(pro)
                    .skyText(.label, color: SkyColor.mossGreenDeep)
                    .frame(width: 80, alignment: .center)
            }
            .padding(.vertical, SkySpacing.s3)

            if !isLast {
                Divider().background(SkyColor.divider)
            }
        }
    }
}

// MARK: - Previews

#Preview("S-PAY-01 Paywall (loading)") {
    PaywallView(onDismiss: {})
        .environmentObject(StoreKitService())
}

#Preview("S-PAY-01 Already Pro") {
    let svc = StoreKitService()
    return PaywallView(onDismiss: {})
        .environmentObject(svc)
}
