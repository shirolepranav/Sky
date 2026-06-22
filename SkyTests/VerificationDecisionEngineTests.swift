// VerificationDecisionEngineTests.swift
// Phase 10 automated tests (Roadmap Phase 10 → Automated Tests).
// Validates VerificationDecisionEngine against all 7 failure reasons, a clean
// pass, and the altitude-rescues-movement edge case.
// Pure struct logic — no async, no mocks, no device I/O required.

import XCTest
@testable import Sky

final class VerificationDecisionEngineTests: XCTestCase {

    private let engine = VerificationDecisionEngine()

    // MARK: - Success

    func testAllSignalsPass() {
        let result = engine.evaluate(sensor: makeSensor(), frame: makeFrame())
        XCTAssertEqual(result, .success(()))
    }

    // MARK: - Sensor failures (checks 1–5)

    func testGPSSpoofingFails() {
        let result = engine.evaluate(sensor: makeSensor(gpsSpoofed: true), frame: makeFrame())
        XCTAssertEqual(result, .failure(.gpsSpoofingDetected))
    }

    func testOutsideDaylightWindowFails() {
        let result = engine.evaluate(sensor: makeSensor(sunriseSunsetCheckPassed: false), frame: makeFrame())
        XCTAssertEqual(result, .failure(.outsideDaylightWindow))
    }

    func testPoorGPSSignalFails() {
        // accuracy of 30.0 m exceeds the 25.0 m threshold
        let result = engine.evaluate(sensor: makeSensor(gpsAccuracyAtBest: 30.0), frame: makeFrame())
        XCTAssertEqual(result, .failure(.poorGPSSignal))
    }

    func testNotEnoughMovementFails() {
        // Both speed (0.1) and altitude (0.3) below their respective thresholds
        let result = engine.evaluate(
            sensor: makeSensor(maxHorizontalSpeed: 0.1, altitudeChangeMeters: 0.3),
            frame: makeFrame()
        )
        XCTAssertEqual(result, .failure(.notEnoughMovement))
    }

    func testMovementFromAltitudeRescues() {
        // Speed below threshold, but altitude above threshold → should pass movement check
        let result = engine.evaluate(
            sensor: makeSensor(maxHorizontalSpeed: 0.1, altitudeChangeMeters: 1.0),
            frame: makeFrame()
        )
        XCTAssertEqual(result, .success(()))
    }

    func testNotBrightEnoughFails() {
        // exposure bias of −1.5 is below the −1.0 threshold
        let result = engine.evaluate(sensor: makeSensor(medianExposureBias: -1.5), frame: makeFrame())
        XCTAssertEqual(result, .failure(.notBrightEnough))
    }

    // MARK: - Vision failures (checks 6–7)

    func testSceneNotOutdoorFails() {
        let result = engine.evaluate(sensor: makeSensor(), frame: makeFrame(outdoorFrameRatio: 0.6))
        XCTAssertEqual(result, .failure(.sceneNotOutdoor))
    }

    func testNoSkyVisibleFails() {
        let result = engine.evaluate(sensor: makeSensor(), frame: makeFrame(maxSkyPixelPercent: 0.05))
        XCTAssertEqual(result, .failure(.noSkyVisible))
    }

    // MARK: - Priority ordering

    func testGPSSpoofingBeatsAllOtherFailures() {
        // Even if every other signal fails, spoofing is reported first.
        let result = engine.evaluate(
            sensor: makeSensor(
                gpsAccuracyAtBest: 100,
                maxHorizontalSpeed: 0,
                altitudeChangeMeters: 0,
                medianExposureBias: -2.0,
                gpsSpoofed: true,
                sunriseSunsetCheckPassed: false
            ),
            frame: makeFrame(outdoorFrameRatio: 0, maxSkyPixelPercent: 0)
        )
        XCTAssertEqual(result, .failure(.gpsSpoofingDetected))
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
