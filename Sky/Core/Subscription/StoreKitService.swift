// StoreKitService.swift
// Core StoreKit 2 service — loads all four Sky Pro tiers, manages purchases,
// maintains the entitlement state, and emits the `isPro` / `currentTier`
// signals that gate Pro features throughout the app.
// Tech Spec §10; Sky_App_Workflow.md §Group G S-PAY-01..05; Roadmap Phase 14.
//
// Call order at app launch (SkyApp.swift):
//   1. storeKit.listenForTransactions()  — background update listener
//   2. try? await storeKit.loadProducts() — fetch store metadata
//   3. await storeKit.refreshEntitlement() — restore any prior purchase

import StoreKit
import Foundation

// MARK: - ProTier

/// Identifies which paid tier is currently active. nil on StoreKitService.currentTier = Free.
enum ProTier: Equatable {
    case monthly(renewalDate: Date?)
    case annual(renewalDate: Date?, isTrial: Bool, trialEndDate: Date?)
    case lifetime
    case founderLifetime
}

// MARK: - PurchaseOutcome

enum PurchaseOutcome {
    case success(ProTier)
    case userCancelled
    case pending        // Ask-to-Buy family approval waiting
    case failed(Error)
}

// MARK: - RestoreOutcome

enum RestoreOutcome {
    case restored
    case nothingFound
    case networkError
}

// MARK: - StoreKitService

@MainActor
final class StoreKitService: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var currentTier: ProTier? = nil
    @Published private(set) var founderSeatsRemaining: Int

    private static let founderSeatsKey     = "founderSeatsRemaining"
    private static let founderSeatsDefault = 500

    let productIDs: [String] = [
        AppBranding.monthlyProductID,
        AppBranding.annualProductID,
        AppBranding.lifetimeProductID,
        AppBranding.founderLifetimeProductID,
    ]

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.founderSeatsKey) as? Int
        founderSeatsRemaining = stored ?? Self.founderSeatsDefault
    }

    // MARK: - Products

    func loadProducts() async throws {
        let loaded = try await Product.products(for: Set(productIDs))
        // Preserve the productIDs display order.
        products = productIDs.compactMap { id in loaded.first { $0.id == id } }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try unwrap(verification)
                await tx.finish()
                await refreshEntitlement()
                return .success(currentTier ?? .lifetime)
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .userCancelled
            }
        } catch {
            return .failed(error)
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var best: ProTier? = nil
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil else { continue }
            if let tier = makeTier(from: tx) {
                best = higherTier(best, tier)
            }
        }
        currentTier = best
        isPro = best != nil
    }

    // MARK: - Transaction listener

    /// Starts a long-running background task that processes StoreKit updates.
    /// Must be called once at app launch; safe to call on any actor.
    nonisolated func listenForTransactions() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            return .networkError
        }
        await refreshEntitlement()
        return isPro ? .restored : .nothingFound
    }

    #if DEBUG
    /// Debug-menu (S-SET-09) override — flip the entitlement locally so Pro-gated
    /// UI can be exercised without a sandbox purchase. Never compiled into release.
    func debugTogglePro() {
        isPro.toggle()
        currentTier = isPro ? .lifetime : nil
    }
    #endif

    // MARK: - Founder seats

    func decrementFounderSeats() {
        guard founderSeatsRemaining > 0 else { return }
        founderSeatsRemaining -= 1
        UserDefaults.standard.set(founderSeatsRemaining, forKey: Self.founderSeatsKey)
    }

    // MARK: - Helpers

    // Fully qualified: the Sky app defines its own `VerificationResult` enum
    // (Features/Verification/VerificationService.swift) which would otherwise
    // shadow StoreKit's generic `VerificationResult<T>`.
    private func unwrap<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    private func makeTier(from tx: Transaction) -> ProTier? {
        switch tx.productID {
        case AppBranding.founderLifetimeProductID:
            return .founderLifetime
        case AppBranding.lifetimeProductID:
            return .lifetime
        case AppBranding.annualProductID:
            let isTrial = tx.offerType == .introductory
            return .annual(
                renewalDate:  tx.expirationDate,
                isTrial:      isTrial,
                trialEndDate: isTrial ? tx.expirationDate : nil
            )
        case AppBranding.monthlyProductID:
            return .monthly(renewalDate: tx.expirationDate)
        default:
            return nil
        }
    }

    /// Returns the tier with higher billing permanence.
    private func higherTier(_ a: ProTier?, _ b: ProTier?) -> ProTier? {
        guard let b else { return a }
        guard let a else { return b }
        return tierRank(a) >= tierRank(b) ? a : b
    }

    private func tierRank(_ tier: ProTier) -> Int {
        switch tier {
        case .founderLifetime: return 4
        case .lifetime:        return 3
        case .annual:          return 2
        case .monthly:         return 1
        }
    }
}
