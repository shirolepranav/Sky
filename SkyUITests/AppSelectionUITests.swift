// AppSelectionUITests.swift
// Phase 3 UI tests (Roadmap Phase 3 → Automated Tests). Launches straight to
// S-CFG-01 (skip onboarding + mock-authorized + clean selection) and verifies
// that tapping "Choose apps" presents Apple's system picker.
//
// XCUITest cannot interact with the FamilyActivityPicker's contents (it is a
// separate, privacy-protected process) — we assert presentation only. The picker
// is also unreliable in the Simulator; run on a device for full coverage.

import XCTest

final class AppSelectionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAtAppSelection() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-mockAuthorized", "-resetSelection"]
        app.launch()
        return app
    }

    func testTappingChooseAppsOpensSystemPicker() {
        let app = launchAtAppSelection()

        let choose = app.buttons["appSelection.choose"]
        XCTAssertTrue(choose.waitForExistence(timeout: 8), "Should land on S-CFG-01")
        XCTAssertTrue(app.staticTexts["appSelection.title"].exists)

        choose.tap()

        // Apple's picker presents as a sheet over the root; the underlying button
        // is no longer hittable once it is covered.
        let covered = NSPredicate(format: "isHittable == false")
        expectation(for: covered, evaluatedWith: choose)
        waitForExpectations(timeout: 8)
    }
}
