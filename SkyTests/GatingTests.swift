// GatingTests.swift
// Unit tests for Free-vs-Pro feature gating (Phase 14).
// No StoreKit session needed — these test pure business logic in ViewModels.
//
// AppSelectionViewModel tests focus on the pure static `isOverFreeLimit`
// function because `FamilyActivitySelection.applicationTokens` uses opaque
// system types that cannot be created in unit tests.
// Roadmap Phase 14.

import XCTest
@testable import Sky

@MainActor
final class GatingTests: XCTestCase {

    // MARK: - AppSelectionViewModel: isOverFreeLimit (pure logic)

    func testFreeCapBlocksMoreThan2() {
        XCTAssertTrue(AppSelectionViewModel.isOverFreeLimit(count: 3,  isPro: false))
        XCTAssertTrue(AppSelectionViewModel.isOverFreeLimit(count: 10, isPro: false))
    }

    func testFreeCapAllows2OrFewer() {
        XCTAssertFalse(AppSelectionViewModel.isOverFreeLimit(count: 2, isPro: false))
        XCTAssertFalse(AppSelectionViewModel.isOverFreeLimit(count: 1, isPro: false))
        XCTAssertFalse(AppSelectionViewModel.isOverFreeLimit(count: 0, isPro: false))
    }

    func testProUserHasNoCapAtAnyCount() {
        XCTAssertFalse(AppSelectionViewModel.isOverFreeLimit(count: 3,  isPro: true))
        XCTAssertFalse(AppSelectionViewModel.isOverFreeLimit(count: 20, isPro: true))
    }
    // Lock-days Pro gate: LimitConfigurationViewModelTests.
}
