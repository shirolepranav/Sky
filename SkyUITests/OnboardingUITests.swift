// OnboardingUITests.swift
// Phase 2 UI tests (Roadmap Phase 2 → Automated Tests).
// Drives the real onboarding flow end-to-end. Launches with -resetOnboarding so
// the OnboardingCompleted flag is cleared and onboarding always appears.

import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetOnboarding"]
        app.launch()
        return app
    }

    /// Swiping advances through all five onboarding pages, ending on the CTA.
    func testSwipeThroughAllFiveScreens() {
        let app = launchApp()

        let titleIDs = [
            "onboarding.title.S-ONB-02",
            "onboarding.title.S-ONB-03",
            "onboarding.title.S-ONB-04",
            "onboarding.title.S-ONB-05",
            "onboarding.title.S-ONB-06",
        ]

        // First page visible.
        XCTAssertTrue(app.staticTexts[titleIDs[0]].waitForExistence(timeout: 5))

        // Swipe through the rest.
        for id in titleIDs.dropFirst() {
            app.swipeLeft()
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 3),
                          "Expected page title \(id) after swipe")
        }

        // Final page shows the CTA instead of the page dots.
        XCTAssertTrue(app.buttons["onboarding.continue"].exists)
    }

    /// Tapping "Let's go" on the final page dismisses onboarding to the main destination.
    func testFinalScreenContinueButtonDismisses() {
        let app = launchApp()

        // Reach the final page.
        for _ in 0..<4 { app.swipeLeft() }

        let cta = app.buttons["onboarding.continue"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5))
        cta.tap()

        // Onboarding is replaced by the (temporary) main destination.
        XCTAssertTrue(app.otherElements["main.placeholder"].waitForExistence(timeout: 5))
    }
}
