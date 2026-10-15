// VerificationDecisionEngineTests.swift
// The three verification checks (DAILY_LOCK_PLAN.md Phase E): GPS, steps, and
// the daylight-only outdoor scene check — plus their priority order.
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
/// `("failure(sceneNotOutdoor)") is not equal to ("success")`.
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

    private func outcome(sensor: SensorReading, frame: FrameAnalysisResult) -> Outcome {
        Outcome(engine.evaluate(sensor: sensor, frame: frame))
    }

    // MARK: - Success

    func testAllSignalsPassingSucceeds() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame()), .success)
    }

    // MARK: - GPS

    func testSpoofedGPSFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsSpoofed: true), frame: makeFrame()),
                       .failure(.gpsSpoofingDetected))
    }

    func testFuzzyGPSFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: 80), frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    /// Loosened from 25 m: a city street or tree cover often reads 30–40 m outdoors.
    func testCityStreetAccuracyPasses() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: 40), frame: makeFrame()), .success)
    }

    func testNoFixAtAllFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: .infinity), frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    func testUnavailableSentinelFails() {
        XCTAssertEqual(outcome(sensor: .unavailable, frame: makeFrame()), .failure(.poorGPSSignal))
    }

    // MARK: - Steps

    func testTooFewStepsFails() {
        XCTAssertEqual(outcome(sensor: makeSensor(recentSteps: 150), frame: makeFrame()),
                       .failure(.notEnoughSteps))
    }

    func testExactlyTheMinimumPasses() {
        XCTAssertEqual(
            outcome(sensor: makeSensor(recentSteps: VerificationThresholds.minRecentSteps), frame: makeFrame()),
            .success
        )
    }

    /// A device with no step counting can't be held to the check.
    func testNoStepCountingIsWaived() {
        XCTAssertEqual(outcome(sensor: makeSensor(recentSteps: nil), frame: makeFrame()), .success)
    }

    func testDeniedMotionAccessAsksForIt() {
        XCTAssertEqual(outcome(sensor: makeSensor(recentSteps: 0, motionDenied: true), frame: makeFrame()),
                       .failure(.motionAccessNeeded))
    }

    // MARK: - Outdoor scene

    func testIndoorSceneFailsInDaylight() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame(outdoorFrameRatio: 0.3)),
                       .failure(.sceneNotOutdoor))
    }

    func testNoSkyFailsInDaylight() {
        XCTAssertEqual(outcome(sensor: makeSensor(), frame: makeFrame(maxSkyPixelPercent: 0.05)),
                       .failure(.sceneNotOutdoor))
    }

    /// The fix for the broken night verification: after dusk the camera can't
    /// see sky, so GPS + steps decide alone.
    func testSceneIsWaivedAfterDark() {
        XCTAssertEqual(
            outcome(sensor: makeSensor(isDaylight: false),
                    frame: makeFrame(outdoorFrameRatio: 0, maxSkyPixelPercent: 0)),
            .success
        )
    }

    func testNightStillNeedsStepsAndGPS() {
        XCTAssertEqual(outcome(sensor: makeSensor(isDaylight: false, recentSteps: 10), frame: makeFrame()),
                       .failure(.notEnoughSteps))
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: 90, isDaylight: false), frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    // MARK: - Priority ordering

    func testGPSSpoofingBeatsAllOtherFailures() {
        XCTAssertEqual(
            outcome(sensor: makeSensor(gpsAccuracyAtBest: 100, gpsSpoofed: true, recentSteps: 0),
                    frame: makeFrame(outdoorFrameRatio: 0, maxSkyPixelPercent: 0)),
            .failure(.gpsSpoofingDetected)
        )
    }

    func testGPSBeatsSteps() {
        XCTAssertEqual(outcome(sensor: makeSensor(gpsAccuracyAtBest: 100, recentSteps: 0), frame: makeFrame()),
                       .failure(.poorGPSSignal))
    }

    func testStepsBeatScene() {
        XCTAssertEqual(outcome(sensor: makeSensor(recentSteps: 0), frame: makeFrame(outdoorFrameRatio: 0)),
                       .failure(.notEnoughSteps))
    }

    // MARK: - Factory helpers

    /// An all-passing SensorReading with named overrides.
    private func makeSensor(
        gpsAccuracyAtBest: Double = 8.0,
        gpsSpoofed: Bool = false,
        isDaylight: Bool = true,
        recentSteps: Int? = 450,
        motionDenied: Bool = false
    ) -> SensorReading {
        SensorReading(
            gpsAccuracyAtBest: gpsAccuracyAtBest,
            gpsSpoofed: gpsSpoofed,
            isDaylight: isDaylight,
            recentSteps: recentSteps,
            motionDenied: motionDenied
        )
    }

    /// An all-passing FrameAnalysisResult with named overrides.
    private func makeFrame(
        outdoorFrameRatio: Double = 0.92,
        maxSkyPixelPercent: Double = 0.22
    ) -> FrameAnalysisResult {
        FrameAnalysisResult(
            outdoorFrameRatio: outdoorFrameRatio,
            maxSkyPixelPercent: maxSkyPixelPercent,
            analyzedFrameCount: 30
        )
    }
}
