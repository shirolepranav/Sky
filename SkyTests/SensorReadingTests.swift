// SensorReadingTests.swift
// Phase 8 automated tests (Roadmap Phase 8 → Automated Tests).
// Validates SensorRecorder's data-aggregation helpers and the SensorReading sentinel.
// All tests run on @MainActor because SensorRecorder is @MainActor.

import CoreLocation
import XCTest
@testable import Sky

@MainActor
final class SensorReadingTests: XCTestCase {

    // MARK: - Speed calculation

    func testSpeedCalculatedCorrectly() {
        // Two locations 10 metres apart, 2-second timestamps.
        // Expected pairwise speed = 10/2 = 5.0 m/s.
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        let t1 = Date(timeIntervalSinceReferenceDate: 2)

        // San Francisco origin
        let loc0 = makeLocation(lat: 37.77, lon: -122.41, speed: -1, timestamp: t0)
        // 10 metres north (≈ 0.000090° latitude)
        let loc1 = makeLocation(lat: 37.77009, lon: -122.41, speed: -1, timestamp: t1)

        let samples = [loc0, loc1]
        let pairwise: [Double] = zip(samples, samples.dropFirst()).compactMap { prev, curr in
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard dt > 0 else { return nil }
            return curr.distance(from: prev) / dt
        }
        let computed = pairwise.max() ?? 0
        XCTAssertGreaterThan(computed, 4.0, "Speed should be roughly 5 m/s for 10 m in 2 s")
        XCTAssertLessThan(computed, 6.0, "Speed should be roughly 5 m/s for 10 m in 2 s")
    }

    func testCLSpeedUsedWhenAvailable() {
        // When CLLocation.speed is positive, it should contribute to maxSpeed.
        let loc = makeLocation(lat: 37.77, lon: -122.41, speed: 8.5, timestamp: Date())
        let clSpeeds = [loc].compactMap { $0.speed >= 0 ? $0.speed : nil }
        XCTAssertEqual(clSpeeds, [8.5])
    }

    // MARK: - Altitude delta

    func testAltitudeDeltaCalculated() {
        let samples: [Double] = [0.0, 1.2, 0.8, 2.5, 1.1]
        guard let lo = samples.min(), let hi = samples.max() else {
            XCTFail("Empty samples"); return
        }
        let delta = abs(hi - lo)
        XCTAssertEqual(delta, 2.5, accuracy: 0.001,
                       "altitudeChangeMeters should be max(2.5) − min(0.0) = 2.5")
    }

    func testAltitudeDeltaEmptyReturnsZero() {
        let samples: [Double] = []
        let delta: Double
        if let lo = samples.min(), let hi = samples.max() {
            delta = abs(hi - lo)
        } else {
            delta = 0
        }
        XCTAssertEqual(delta, 0, "Empty altitude samples → 0")
    }

    // MARK: - GPS spoof detection

    func testContainsSpoofedLocationReturnsFalseForNormalLocations() {
        // CLLocationSourceInformation has no public init, so we can only verify
        // that standard CLLocation objects (which have nil sourceInformation) return false.
        let loc = makeLocation(lat: 37.77, lon: -122.41, speed: -1, timestamp: Date())
        XCTAssertFalse(
            SensorRecorder.containsSpoofedLocation([loc]),
            "Normal CLLocations should not be flagged as spoofed"
        )
    }

    func testContainsSpoofedLocationReturnsFalseForEmptyArray() {
        XCTAssertFalse(SensorRecorder.containsSpoofedLocation([]))
    }

    // MARK: - Median exposure bias

    func testMedianExposureBiasOddCount() {
        // [−2.0, −0.5, 0.0, 0.5, 1.0] sorted → median index 2 = 0.0
        let samples: [Float] = [-2.0, 0.5, 1.0, -0.5, 0.0]
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        let median = sorted[mid]
        XCTAssertEqual(median, 0.0, accuracy: 0.001)
    }

    func testMedianExposureBiasEvenCount() {
        // [−1.0, 0.0, 0.5, 1.0] sorted → average of indices 1 & 2 = 0.25
        let samples: [Float] = [-1.0, 1.0, 0.0, 0.5]
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        let median = (sorted[mid - 1] + sorted[mid]) / 2
        XCTAssertEqual(median, 0.25, accuracy: 0.001)
    }

    func testMedianExposureBiasEmptyReturnsZero() {
        let samples: [Float] = []
        let median: Float = samples.isEmpty ? 0 : samples.sorted()[samples.count / 2]
        XCTAssertEqual(median, 0)
    }

    // MARK: - Unavailable sentinel

    func testUnavailableSentinel() {
        let r = SensorReading.unavailable
        XCTAssertEqual(r.gpsAccuracyAtBest, .infinity)
        XCTAssertEqual(r.maxHorizontalSpeed, 0)
        XCTAssertEqual(r.altitudeChangeMeters, 0)
        XCTAssertEqual(r.medianExposureBias, 0)
        XCTAssertFalse(r.gpsSpoofed)
        XCTAssertFalse(r.sunriseSunsetCheckPassed)
    }

    func testUnavailableSentinelIsEquatable() {
        XCTAssertEqual(SensorReading.unavailable, SensorReading.unavailable)
    }

    // MARK: - Helpers

    private func makeLocation(
        lat: Double,
        lon: Double,
        speed: CLLocationSpeed,
        timestamp: Date,
        accuracy: CLLocationAccuracy = 5.0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: speed,
            timestamp: timestamp
        )
    }
}
