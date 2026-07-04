// StoreKitServiceTests.swift
// Unit tests for StoreKitService using Xcode's StoreKit test framework.
// Each test uses SKTestSession backed by Sky.storekit to simulate purchases
// without hitting the real App Store.
//
// Prerequisites:
//   1. Sky.storekit must be added to the SkyTests target's "Copy Bundle Resources"
//      in Xcode (Product → Edit Scheme → Test → Options → StoreKit Configuration,
//      or add the file to the test target's Build Phases).
//   2. The scheme's StoreKit Configuration must point to Sky.storekit for sandbox use.
//
// Roadmap Phase 14.

import XCTest
import StoreKitTest
@testable import Sky

@MainActor
final class StoreKitServiceTests: XCTestCase {

    private var session: SKTestSession!
    private var service: StoreKitService!

    override func setUp() async throws {
        try await super.setUp()
        session = try SKTestSession(configurationFileNamed: "Sky")
        session.resetToDefaultState()
        session.disableDialogs = true
        service = StoreKitService()
    }

    override func tearDown() async throws {
        session.finish()
        session = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Product loading

    func testLoadProductsFetchesAll4() async throws {
        try await service.loadProducts()
        XCTAssertEqual(service.products.count, 4, "Expected monthly, annual, lifetime, founder")
    }

    func testProductsAreInCorrectOrder() async throws {
        try await service.loadProducts()
        let ids = service.products.map { $0.id }
        XCTAssertEqual(ids, [
            AppBranding.monthlyProductID,
            AppBranding.annualProductID,
            AppBranding.lifetimeProductID,
            AppBranding.founderLifetimeProductID,
        ])
    }

    // MARK: - Purchase flow

    func testPurchaseMonthlyMakesUserPro() async throws {
        try await service.loadProducts()
        try session.buyProduct(productIdentifier: AppBranding.monthlyProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
        guard case .monthly = service.currentTier else {
            XCTFail("Expected .monthly tier, got \(String(describing: service.currentTier))")
            return
        }
    }

    func testPurchaseLifetimeMakesUserPro() async throws {
        try await service.loadProducts()
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
        XCTAssertEqual(service.currentTier, .lifetime)
    }

    func testPurchaseFounderMakesUserProFounderTier() async throws {
        try await service.loadProducts()
        try session.buyProduct(productIdentifier: AppBranding.founderLifetimeProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
        XCTAssertEqual(service.currentTier, .founderLifetime)
    }

    // MARK: - Entitlement detection

    func testRefreshEntitlementDetectsActiveSubscription() async throws {
        try session.buyProduct(productIdentifier: AppBranding.monthlyProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
    }

    func testRefreshEntitlementDetectsActiveLifetime() async throws {
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
        XCTAssertEqual(service.currentTier, .lifetime)
    }

    func testNoEntitlementWhenNoPurchase() async throws {
        // Fresh session — no purchases
        await service.refreshEntitlement()
        XCTAssertFalse(service.isPro)
        XCTAssertNil(service.currentTier)
    }

    // MARK: - Restore

    func testRestoreReturnsNothingFoundWhenEmpty() async throws {
        let outcome = await service.restorePurchases()
        // No purchases in test session → nothingFound
        XCTAssertEqual(outcome, .nothingFound)
    }

    func testRestoreFindsExistingPurchase() async throws {
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        // Simulate a fresh service (e.g., reinstall) — reset state without revoking
        session.resetToDefaultState()
        // On a real device, AppStore.sync() would restore; in tests refreshEntitlement re-scans
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .restored)
    }

    // MARK: - Founder seats

    func testFounderSeatsDecrementOnPurchase() async throws {
        // Clear any stored count
        UserDefaults.standard.removeObject(forKey: "founderSeatsRemaining")
        service = StoreKitService()  // fresh service reads default (500)
        XCTAssertEqual(service.founderSeatsRemaining, 500)

        service.decrementFounderSeats()
        XCTAssertEqual(service.founderSeatsRemaining, 499)
    }

    func testFounderSeatsDoNotGoBelowZero() async throws {
        UserDefaults.standard.set(0, forKey: "founderSeatsRemaining")
        service = StoreKitService()
        service.decrementFounderSeats()
        XCTAssertEqual(service.founderSeatsRemaining, 0)
    }
}

// MARK: - RestoreOutcome: Equatable (for test assertions)

extension RestoreOutcome: Equatable {
    public static func == (lhs: RestoreOutcome, rhs: RestoreOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.restored, .restored),
             (.nothingFound, .nothingFound),
             (.networkError, .networkError):
            return true
        default:
            return false
        }
    }
}
