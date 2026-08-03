// StoreKitService.swift
// Core StoreKit 2 service — loads the single Sky Pro product, manages the
// purchase, maintains the entitlement state, and emits the `isPro` signal that
// gates Pro features throughout the app.
// Tech Spec §10; Sky_App_Workflow.md §Group G S-PAY-01/03/05; Roadmap Phase 14.
//
// Sky Pro is ONE non-consumable one-time purchase. There are no subscriptions,
// no tiers to rank, and no free trial (Apple does not support introductory
// offers on non-consumables — the free tier is the trial). That makes `isPro`
// the only entitlement signal the rest of the app needs; every gate in the app
// takes a plain `Bool`.
//
// Call order at app launch (SkyApp.swift):
//   1. storeKit.listenForTransactions()  — background update listener
//   2. try? await storeKit.loadProducts() — fetch store metadata
//   3. await storeKit.refreshEntitlement() — restore any prior purchase

import StoreKit
import Foundation

// MARK: - PurchaseOutcome

enum PurchaseOutcome {
    case success
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

    let productIDs: [String] = [AppBranding.lifetimeProductID]

    // MARK: - Products

    func loadProducts() async throws {
        let loaded = try await Product.products(for: Set(productIDs))
        // Preserve the productIDs display order.
        products = productIDs.compactMap { id in loaded.first { $0.id == id } }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// The one Sky Pro product, when StoreKit metadata is available.
    var proProduct: Product? { product(for: AppBranding.lifetimeProductID) }

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
                return .success
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
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil,
                  tx.productID == AppBranding.lifetimeProductID else { continue }
            entitled = true
            break
        }
        isPro = entitled
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

    /// Required by App Review for a non-consumable — it is the only way a user
    /// on a new device recovers their purchase.
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
    /// Debug-menu (S-SET-09) override — set the entitlement locally so Pro-gated
    /// UI (and the paywall's "Already Pro" variant) can be exercised without a
    /// sandbox purchase. Never compiled into release.
    func debugSetPro(_ pro: Bool) {
        isPro = pro
    }

    func debugTogglePro() {
        debugSetPro(!isPro)
    }
    #endif

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
}
