// SensorReadingTests.swift
// SensorRecorder's spoof check and the SensorReading sentinel (DAILY_LOCK_PLAN.md
// Phase E). The GPS and pedometer streams themselves need a device.

import CoreLocation
import XCTest
@testable import Sky

@MainActor
final class SensorReadingTests: XCTestCase {

    // MARK: - GPS spoof detection

    func testContainsSpoofedLocationReturnsFalseForNormalLocations() {
        // CLLocationSourceInformation has no public init, so only the negative case
        // (nil sourceInformation) can be built here.
        let loc = CLLocation(latitude: 37.77, longitude: -122.41)
        XCTAssertFalse(SensorRecorder.containsSpoofedLocation([loc]))
    }

    func testContainsSpoofedLocationReturnsFalseForEmptyArray() {
        XCTAssertFalse(SensorRecorder.containsSpoofedLocation([]))
    }

    // MARK: - Unavailable sentinel

    /// The simulator / mock sentinel must fail verification, never pass it.
    func testUnavailableSentinelFailsVerification() {
        let r = SensorReading.unavailable
        XCTAssertEqual(r.gpsAccuracyAtBest, .infinity)
        XCTAssertEqual(r.recentSteps, 0)
        XCTAssertFalse(r.gpsSpoofed)
        XCTAssertFalse(r.isDaylight)
    }

    func testUnavailableSentinelIsEquatable() {
        XCTAssertEqual(SensorReading.unavailable, SensorReading.unavailable)
    }
}
