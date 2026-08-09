// PaywallView.swift
// S-PAY-01 — Full paywall presented as a .fullScreenCover. Sky Pro is a single
// one-time purchase, so there is one price card, no trial, and no tier choice.
// One-shot post-verification upsell and all Pro-gate entry points land here.
// Sky_App_Workflow.md §Group G S-PAY-01; Roadmap Phase 14.

import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    let onDismiss: () -> Void

    @State private var isPurchasing: Bool = false
    @State private var loadError: Bool = false
    @State private var didAttemptLoad: Bool = false
    @State private var restoreOutcome: RestoreOutcome? = nil
    @State private var showRestoreSheet: Bool = false

    // Spin only until the first load attempt finishes. If StoreKit returns no
    // products without throwing, we stop spinning and fall back to a static price
    // (see FallbackPricing) instead of hanging forever.
    private var isLoading: Bool { !didAttemptLoad && storeKit.products.isEmpty && !loadError }
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
        .task {
            if storeKit.products.isEmpty {
                do {
                    try await storeKit.loadProducts()
                } catch {
                    loadError = true
                }
            }
            didAttemptLoad = true
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
                    priceSection
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

            Text("One purchase. Yours forever.")
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

    // MARK: - Price

    private var priceSection: some View {
        ProPriceCardView(
            product: storeKit.proProduct,
            isLoading: isLoading,
            fallback: FallbackPricing.price(for: AppBranding.lifetimeProductID),
            action: handlePurchase
        )
        .disabled(isPurchasing)
        .overlay {
            if isPurchasing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SkyColor.surface.opacity(0.6))
            }
        }
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
                    feature: "Session limits",
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

    // Sky Pro is a non-consumable: nothing auto-renews and there is nothing to
    // cancel. Saying otherwise would be false and is a review risk.
    private var legalFooter: some View {
        Text("One-time purchase. Not a subscription. Terms · Privacy.")
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
                    didAttemptLoad = false
                    Task {
                        do { try await storeKit.loadProducts() }
                        catch { loadError = true }
                        didAttemptLoad = true
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

            Spacer()

            SkyPrimaryButton("Done", action: onDismiss)
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
        }
        .padding(.top, SkySpacing.s10)
        .accessibilityIdentifier("paywall.alreadyPro")
    }

    // MARK: - Actions

    private func handlePurchase() {
        guard let product = storeKit.proProduct else {
            #if DEBUG
            // No live StoreKit product (e.g. Simulator without the .storekit config)
            // — grant Pro so the paywall flow stays exercisable in Debug.
            storeKit.debugSetPro(true)
            onDismiss()
            #endif
            return
        }
        isPurchasing = true
        Task {
            let outcome = await storeKit.purchase(product)
            isPurchasing = false

            switch outcome {
            case .success:
                onDismiss()
            case .userCancelled, .pending, .failed:
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

#Preview("S-PAY-01 Paywall") {
    PaywallView(onDismiss: {})
        .environmentObject(StoreKitService())
}

#Preview("S-PAY-01 Paywall — dark") {
    PaywallView(onDismiss: {})
        .environmentObject(StoreKitService())
        .preferredColorScheme(.dark)
}
