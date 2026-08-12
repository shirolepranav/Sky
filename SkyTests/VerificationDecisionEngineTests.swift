// VerificationDecisionEngineTests.swift
// Phase 10 automated tests (Roadmap Phase 10 → Automated Tests).
// Validates VerificationDecisionEngine against all 7 failure reasons, a clean
// pass, and the altitude-rescues-movement edge case.
// Pure struct logic — no async, no mocks, no device I/O required.

import XCTest
@testable import Sky

/// `VerificationDecisionEngine.evaluate` returns `Result<Void, FailureReason>`,
/// which cannot be passed to `XCTAssertEqual`: `Void` isn't `Equatable`, and
/// `Result`'s own conditional conformance (`Success: Equatable, Failure:
/// Equatable`) can't be widened to cover `Success == Void` — a second
/// conformance would be redundant and won't compile.
///
/// Collapsing to this shadow enum keeps every assertion a one-liner and keeps
/// the failure output legible, e.g.
/// `("failure(noSkyVisible)") is not equal to ("success")`.
private enum Outcome: Equatable {
    case success
    case failure(FailureReason)

    init(_ result: Result<Void, FailureReason>) {
        switch result {
        case .success:             self = .success
        case .failure(let reason): self = .failure(reason)
        }
    }
}

final class VerificationDecisionEngineTests: XCTestCase {

    private let engine = VerificationDecisionEngine()

    /// Evaluates and collapses to the Equatable `Outcome` in one step.
    private func outcome(
        sensor: SensorReading,
        frame: FrameAnalysisResult,
        nightModeEnabled: Bool = false
    ) -> Outcome {
        Outcome(engine.evaluate(sensor: sensor, frame: frame, nightModeEnabled: nightModeEnabled))
    }

    // MARK: - Success

    func testAllSignalsPass() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame()), .success)
    }

    // MARK: - Sensor failures (checks 1–5)

    func testGPSSpoofingFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsSpoofed: true), frame: makeFrame()),
                       .failure(.gpsSpoofingDetected))
    }

    func testOutsideDaylightWindowFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(sunriseSunsetCheckPassed: false), frame: makeFrame()),
                       .failure(.outsideDaylightWindow))
    }

    func testPoorGPSSignalFails() {
        // accuracy of 30.0 m exceeds the 25.0 m threshold
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: 30.0), frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    /// When no location fix ever arrives, `SensorRecorder` reports
    /// `gpsAccuracyAtBest == .infinity` AND `sunriseSunsetCheckPassed == false` —
    /// the latter only because the daylight check needs a coordinate it never got.
    /// The engine must attribute this to GPS, not to darkness; before the check
    /// reorder this told a user at noon "It's dark out."
    func testNoGPSFixReportsPoorSignalNotDarkness() {
        XCTAssertEqual(
            outcome(sensor: makeSensor(gpsAccuracyAtBest: .infinity,
                                       sunriseSunsetCheckPassed: false),
                    frame: makeFrame()),
            .failure(.poorGPSSignal)
        )
    }

    /// The same no-fix reading with Night Mode on must still blame GPS — night mode
    /// waives the daylight check, so nothing else would catch a missing fix.
    func testNoGPSFixReportsPoorSignalUnderNightMode() {
        XCTAssertEqual(
            outcome(sensor: makeSensor(gpsAccuracyAtBest: .infinity,
                                       sunriseSunsetCheckPassed: false),
                    frame: makeFrame(),
                    nightModeEnabled: true),
            .failure(.poorGPSSignal)
        )
    }

    /// `SensorReading.unavailable` is the sentinel used on Simulator and in mocks.
    /// It carries infinite accuracy, so it must read as a GPS failure.
    func testUnavailableSentinelReportsPoorGPSSignal() {
        XCTAssertEqual(outcome(sensor: .unavailable, frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    func testNotEnoughMovementFails() {
        // Both speed (0.1) and altitude (0.3) below their respective thresholds
        XCTAssertEqual(
            outcome(sensor: makeSensor(maxHorizontalSpeed: 0.1, altitudeChangeMeters: 0.3),
                    frame: makeFrame()),
            .failure(.notEnoughMovement)
        )
    }

    func testMovementFromAltitudeRescues() {
        // Speed below threshold, but altitude above threshold → should pass movement check
        XCTAssertEqual(
            outcome(sensor: makeSensor(maxHorizontalSpeed: 0.1, altitudeChangeMeters: 1.0),
                    frame: makeFrame()),
            .success
        )
    }

    func testNotBrightEnoughFails() {
        // exposure bias of −1.5 is below the −1.0 threshold
        XCTAssertEqual(outcome(sensor: makeSensor(medianExposureBias: -1.5), frame: makeFrame()),
                       .failure(.notBrightEnough))
    }

    // MARK: - Vision failures (checks 6–7)

    func testSceneNotOutdoorFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame(outdoorFrameRatio: 0.6)),
                       .failure(.sceneNotOutdoor))
    }

    func testNoSkyVisibleFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame(maxSkyPixelPercent: 0.05)),
                       .failure(.noSkyVisible))
    }

    // MARK: - Night Mode (Phase 15)

    func testNightModeBypassesDaylight() {
        // Same failing daylight signal passes once Night Mode waives that one check.
        let sensor = makeSensor(sunriseSunsetCheckPassed: false)
        XCTAssertEqual(
            outcome(sensor: sensor, frame: makeFrame(), nightModeEnabled: false),
            .failure(.outsideDaylightWindow)
        )
        XCTAssertEqual(
            outcome(sensor: sensor, frame: makeFrame(), nightModeEnabled: true),
            .success
        )
    }

    func testNightModeDoesNotWaiveOtherChecks() {
        // Night Mode only affects the daylight check — movement still required.
        let sensor = makeSensor(
            maxHorizontalSpeed: 0.1, altitudeChangeMeters: 0.3,
            sunriseSunsetCheckPassed: false
        )
        XCTAssertEqual(
            outcome(sensor: sensor, frame: makeFrame(), nightModeEnabled: true),
            .failure(.notEnoughMovement)
        )
    }

    // MARK: - Priority ordering

    func testGPSSpoofingBeatsAllOtherFailures() {
        // Even if every other signal fails, spoofing is reported first.
        XCTAssertEqual(
            outcome(
                sensor: makeSensor(
                    gpsAccuracyAtBest: 100,
                    maxHorizontalSpeed: 0,
                    altitudeChangeMeters: 0,
                    medianExposureBias: -2.0,
                    gpsSpoofed: true,
                    sunriseSunsetCheckPassed: false
                ),
                frame: makeFrame(outdoorFrameRatio: 0, maxSkyPixelPercent: 0)
            ),
            .failure(.gpsSpoofingDetected)
        )
    }

    // MARK: - Factory helpers

    /// Returns an all-passing SensorReading with named overrides.
    private func makeSensor(
        gpsAccuracyAtBest: Double = 8.0,
        maxHorizontalSpeed: Double = 1.2,
        altitudeChangeMeters: Double = 1.5,
        medianExposureBias: Float = 0.2,
        gpsSpoofed: Bool = false,
        sunriseSunsetCheckPassed: Bool = true
    ) -> SensorReading {
        SensorReading(
            gpsAccuracyAtBest: gpsAccuracyAtBest,
            maxHorizontalSpeed: maxHorizontalSpeed,
            altitudeChangeMeters: altitudeChangeMeters,
            medianExposureBias: medianExposureBias,
            timeOfDay: Date(),
            gpsSpoofed: gpsSpoofed,
            sunriseSunsetCheckPassed: sunriseSunsetCheckPassed
        )
    }

    /// Returns an all-passing FrameAnalysisResult with named overrides.
    private func makeFrame(
        outdoorFrameRatio: Double = 0.92,
        maxSkyPixelPercent: Double = 0.22
    ) -> FrameAnalysisResult {
        FrameAnalysisResult(
            outdoorFrameRatio: outdoorFrameRatio,
            maxSkyPixelPercent: maxSkyPixelPercent,
            analyzedFrameCount: 180
        )
    }
}
