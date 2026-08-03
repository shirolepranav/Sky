// StoreKitServiceTests.swift
// Unit tests for StoreKitService using Xcode's StoreKit test framework.
// Each test uses SKTestSession backed by Sky.storekit to simulate purchases
// without hitting the real App Store.
//
// Sky Pro is a single non-consumable, so there are no tiers, no subscription
// renewals, and no trial to assert on — only "does the entitlement resolve".
//
// ⚠️ RUN THESE ON iOS 26.2, NOT 26.5.
// StoreKit Testing is broken in the **iOS 26.5 simulator runtime**: `SKTestSession`
// connects to `com.apple.storekit.configuration.xpc` successfully, but storekitd
// rejects the very first "save configuration" request with
// `SKInternalErrorDomain Code=3`, leaving the session with an empty storefront and
// zero products. The same code, config file, and scheme work perfectly on iOS 26.2.
// It is an Apple runtime bug — not a project or configuration defect (verified by
// erasing the device, restarting CoreSimulatorService, and trying every session
// initializer and both a scheme reference and a test plan).
//
// `skipIfStoreKitTestingIsBroken()` detects that state and skips, so a bad runtime
// reports honestly instead of failing red. On a good runtime nothing skips and all
// assertions run for real. See CLAUDE.md → Build & verify for the destination to use.
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
        // Sky.storekit is a resource of the host app (Sky.app). It also lands in
        // the xctest bundle, but resolving explicitly keeps this working either way.
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "Sky", withExtension: "storekit")
                ?? Bundle(for: Self.self).url(forResource: "Sky", withExtension: "storekit"),
            "Sky.storekit not found in the host app or test bundle"
        )
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        service = StoreKitService()
    }

    override func tearDown() async throws {
        // SKTestSession has no explicit teardown call in the current SDK —
        // clearing transactions and dropping the reference is the supported path.
        session.clearTransactions()
        session = nil
        service = nil
        try await super.tearDown()
    }

    /// Skips when the simulator runtime's StoreKit test service is non-functional
    /// (see the iOS 26.5 note in the file header). An empty storefront is the
    /// signature: a working session always reports one, e.g. "USA".
    private func skipIfStoreKitTestingIsBroken() throws {
        try XCTSkipIf(
            session.storefront.isEmpty,
            "StoreKit Testing is non-functional on this simulator runtime (known iOS 26.5 bug) — run these on iOS 26.2."
        )
    }

    // MARK: - Product loading

    func testLoadProductsFetchesTheSingleProSKU() async throws {
        try skipIfStoreKitTestingIsBroken()
        try await service.loadProducts()
        XCTAssertEqual(service.products.count, 1, "Sky Pro is one non-consumable")
        XCTAssertEqual(service.products.first?.id, AppBranding.lifetimeProductID)
    }

    /// The convenience accessor the paywall reads must resolve after a load.
    func testProProductResolvesAfterLoad() async throws {
        try skipIfStoreKitTestingIsBroken()
        XCTAssertNil(service.proProduct, "No product should resolve before loading")
        try await service.loadProducts()
        XCTAssertNotNil(service.proProduct)
    }

    /// Guards the price the paywall falls back to when StoreKit metadata is absent.
    func testFallbackPriceMatchesTheStoreKitConfiguration() async throws {
        try skipIfStoreKitTestingIsBroken()
        try await service.loadProducts()
        XCTAssertEqual(
            FallbackPricing.price(for: AppBranding.lifetimeProductID)?.displayPrice,
            service.proProduct?.displayPrice,
            "FallbackPricing has drifted from Sky.storekit"
        )
    }

    /// Nothing in the config may be a subscription — a renewing product would
    /// re-introduce the auto-renew legal copy the paywall no longer shows.
    func testProProductIsNotASubscription() async throws {
        try skipIfStoreKitTestingIsBroken()
        try await service.loadProducts()
        XCTAssertNotNil(service.proProduct, "Precondition: the product must load")
        XCTAssertNil(service.proProduct?.subscription,
                     "Sky Pro must stay a non-consumable one-time purchase")
    }

    // MARK: - Purchase flow

    func testPurchaseMakesUserPro() async throws {
        try skipIfStoreKitTestingIsBroken()
        try await service.loadProducts()
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
    }

    // MARK: - Entitlement detection

    func testRefreshEntitlementDetectsExistingPurchase() async throws {
        try skipIfStoreKitTestingIsBroken()
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPro)
    }

    /// Runs without a product — a fresh install must not be entitled.
    func testNoEntitlementWhenNoPurchase() async throws {
        await service.refreshEntitlement()
        XCTAssertFalse(service.isPro)
    }

    // Not covered: the refund/revocation path. `refreshEntitlement()` filters on
    // `tx.revocationDate == nil`, but SKTestSession reports `identifier == 0` for
    // its transactions here, so `refundTransaction(identifier:)` is a no-op and
    // any such test would assert nothing. Verify refunds manually in sandbox.

    // MARK: - Restore

    func testRestoreFindsExistingPurchase() async throws {
        try skipIfStoreKitTestingIsBroken()
        try session.buyProduct(productIdentifier: AppBranding.lifetimeProductID)
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .restored)
    }

    /// Note: `AppStore.sync()` hangs on a runtime where StoreKit Testing is
    /// broken, so the skip guard above must stay ahead of it.
    func testRestoreReturnsNothingFoundWhenEmpty() async throws {
        try skipIfStoreKitTestingIsBroken()
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .nothingFound)
    }
}

// `RestoreOutcome` has no associated values, so Swift synthesizes `Equatable`
// automatically — no manual conformance needed here.
