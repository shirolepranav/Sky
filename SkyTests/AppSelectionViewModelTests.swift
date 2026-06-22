// AppSelectionViewModelTests.swift
// Phase 3 automated tests (Roadmap Phase 3 → Automated Tests). Verifies the
// app-selection view model's persistence, count/empty derivation, and the
// invalid-data "needs redo" surface. Uses an isolated suite.

import XCTest
import FamilyControls
@testable import Sky

@MainActor
final class AppSelectionViewModelTests: XCTestCase {
    private let suiteName = "AppSelectionViewModelTests"
    private var defaults: UserDefaults!
    private var store: SharedDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedDefaults(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    /// Fresh store → empty selection, Continue disabled.
    func testEmptyStartState() {
        let vm = AppSelectionViewModel(store: store)
        XCTAssertTrue(vm.isEmpty)
        XCTAssertEqual(vm.count, 0)
        XCTAssertFalse(vm.canContinue)
        XCTAssertFalse(vm.needsRedo)
    }

    /// Persisting writes the selection through to SharedDefaults.
    func testPersistWritesToSharedDefaults() {
        let vm = AppSelectionViewModel(store: store)
        vm.selection = FamilyActivitySelection()
        vm.persistSelection()

        XCTAssertNotNil(store.familyActivitySelection)
        XCTAssertFalse(vm.needsRedo)
    }

    /// Corrupt stored Data flags the "needs redoing after an iOS update" state and
    /// keeps Continue disabled until re-picked.
    func testInvalidStoredDataSurfacesNeedsRedo() {
        store.familyActivitySelection = Data("garbage".utf8)
        let vm = AppSelectionViewModel(store: store)

        XCTAssertTrue(vm.needsRedo)
        XCTAssertFalse(vm.canContinue)

        // Re-picking and persisting clears the warning.
        vm.selection = FamilyActivitySelection()
        vm.persistSelection()
        XCTAssertFalse(vm.needsRedo)
    }
}
