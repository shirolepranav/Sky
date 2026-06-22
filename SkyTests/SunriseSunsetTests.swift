// SunriseSunsetTests.swift
// Phase 8 automated tests (Roadmap Phase 8 → Automated Tests).
// Validates SolarCalculator against 5 published NOAA sunrise/sunset times.
// Accuracy requirement: ±2 minutes (120 seconds) per the Roadmap.

import CoreLocation
import XCTest
@testable import Sky

final class SunriseSunsetTests: XCTestCase {

    private let toleranceSeconds: TimeInterval = 120  // ±2 minutes

    // MARK: - Five NOAA reference vectors

    /// Verify sunrise and sunset against published NOAA tables for 5 diverse locations.
    func testKnownLocationsAndDates() throws {
        struct Vector {
            let name: String
            let lat: Double
            let lon: Double
            let year: Int
            let month: Int
            let day: Int
            let tzID: String
            // Expected times expressed as UTC hours and minutes on the reference day
            // (or next day for certain sunset times — accounted for via toleranceSeconds).
            let sunriseUTCMinutes: Int   // minutes since midnight UTC
            let sunsetUTCMinutes: Int    // minutes since midnight UTC (may be next day → > 1440)
        }

        let vectors: [Vector] = [
            // 1. San Francisco, CA — summer solstice 2024
            //    Sunrise ~05:47 PDT = 12:47 UTC; Sunset ~20:35 PDT = 03:35+1 UTC
            Vector(name: "SF Summer",
                   lat: 37.77, lon: -122.41,
                   year: 2024, month: 6, day: 21,
                   tzID: "America/Los_Angeles",
                   sunriseUTCMinutes: 12 * 60 + 47,
                   sunsetUTCMinutes:  (24 + 3) * 60 + 35),  // 03:35 next-day UTC

            // 2. Helsinki, Finland — winter solstice 2024
            //    Sunrise ~09:23 EET = 07:23 UTC; Sunset ~14:10 EET = 12:10 UTC
            Vector(name: "Helsinki Winter",
                   lat: 60.17, lon: 24.94,
                   year: 2024, month: 12, day: 21,
                   tzID: "Europe/Helsinki",
                   sunriseUTCMinutes: 7 * 60 + 23,
                   sunsetUTCMinutes:  12 * 60 + 10),

            // 3. Singapore — March equinox 2024
            //    Sunrise ~07:12 SGT = 23:12-1 UTC (prev day); Sunset ~19:20 SGT = 11:20 UTC
            Vector(name: "Singapore Equinox",
                   lat: 1.35, lon: 103.82,
                   year: 2024, month: 3, day: 21,
                   tzID: "Asia/Singapore",
                   sunriseUTCMinutes: 23 * 60 + 12,  // same UTC midnight, hours 23:12
                   sunsetUTCMinutes:  11 * 60 + 20),

            // 4. Denver, CO — winter solstice 2024
            //    Sunrise ~07:17 MST = 14:17 UTC; Sunset ~16:41 MST = 23:41 UTC
            Vector(name: "Denver Winter",
                   lat: 39.73, lon: -104.98,
                   year: 2024, month: 12, day: 21,
                   tzID: "America/Denver",
                   sunriseUTCMinutes: 14 * 60 + 17,
                   sunsetUTCMinutes:  23 * 60 + 41),

            // 5. Oslo, Norway — summer solstice 2024 (near-midnight-sun)
            //    Sunrise ~03:56 CEST = 01:56 UTC; Sunset ~22:51 CEST = 20:51 UTC
            Vector(name: "Oslo Summer",
                   lat: 59.91, lon: 10.75,
                   year: 2024, month: 6, day: 21,
                   tzID: "Europe/Oslo",
                   sunriseUTCMinutes: 1 * 60 + 56,
                   sunsetUTCMinutes:  20 * 60 + 51),
        ]

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        for v in vectors {
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(identifier: v.tzID)!
            let comps = DateComponents(year: v.year, month: v.month, day: v.day,
                                       hour: 12, minute: 0, second: 0)
            guard let localNoon = localCal.date(from: comps) else {
                XCTFail("\(v.name): could not build reference date"); continue
            }

            let calc = SolarCalculator(
                coordinate: CLLocationCoordinate2D(latitude: v.lat, longitude: v.lon),
                date: localNoon,
                timeZone: TimeZone(identifier: v.tzID)!
            )

            // Check sunrise
            if let rise = calc.sunrise() {
                let riseComps = utcCal.dateComponents([.hour, .minute], from: rise)
                let riseMinutes = (riseComps.hour ?? 0) * 60 + (riseComps.minute ?? 0)
                let diff = abs(riseMinutes - v.sunriseUTCMinutes)
                // Allow wrap-around at midnight (diff can be up to 1440 - actual diff)
                let adjustedDiff = min(diff, 1440 - diff)
                XCTAssertLessThanOrEqual(
                    Double(adjustedDiff) * 60, toleranceSeconds,
                    "\(v.name): sunrise off by \(adjustedDiff) min (expected \(v.sunriseUTCMinutes) UTC min, got \(riseMinutes))"
                )
            } else {
                XCTFail("\(v.name): sunrise() returned nil (polar night/day?) — check the vector date/location")
            }

            // Check sunset
            if let set = calc.sunset() {
                // sunset may be next-day UTC → compare modulo 1440
                let setComps = utcCal.dateComponents([.hour, .minute], from: set)
                let setMinutes = (setComps.hour ?? 0) * 60 + (setComps.minute ?? 0)
                let expectedMod = v.sunsetUTCMinutes % 1440
                let diff = abs(setMinutes - expectedMod)
                let adjustedDiff = min(diff, 1440 - diff)
                XCTAssertLessThanOrEqual(
                    Double(adjustedDiff) * 60, toleranceSeconds,
                    "\(v.name): sunset off by \(adjustedDiff) min (expected \(expectedMod) UTC min, got \(setMinutes))"
                )
            } else {
                XCTFail("\(v.name): sunset() returned nil")
            }
        }
    }

    // MARK: - Daylight check

    func testDaylightCheckPasses_SFMidday() {
        // San Francisco at noon local time on any regular summer day — must be daylight.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: 2024, month: 6, day: 21, hour: 12)
        guard let noon = cal.date(from: comps) else { XCTFail(); return }

        let calc = SolarCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),
            date: noon,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        )
        XCTAssertTrue(calc.isCurrentlyDaylight(), "SF at noon should be daylight")
    }

    func testDaylightCheckFails_SFMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: 2024, month: 6, day: 21, hour: 2)
        guard let twoAM = cal.date(from: comps) else { XCTFail(); return }

        let calc = SolarCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),
            date: twoAM,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        )
        XCTAssertFalse(calc.isCurrentlyDaylight(), "SF at 2 AM should be dark")
    }

    // MARK: - Polar edge cases

    func testPolarNightHandled() {
        // Near the North Pole in December — polar night. sunrise() must return nil, not crash.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 12, day: 21, hour: 12)
        guard let date = cal.date(from: comps) else { XCTFail(); return }

        let calc = SolarCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0.0),
            date: date,
            timeZone: .current
        )
        // Should not crash; returns nil for both
        XCTAssertNil(calc.sunrise(), "89°N in December is polar night — no sunrise")
        XCTAssertNil(calc.sunset(), "89°N in December is polar night — no sunset")
        XCTAssertFalse(calc.isCurrentlyDaylight(), "Polar night → not daylight")
    }

    func testMidnightSunHandled() {
        // Near the North Pole in June — midnight sun. isCurrentlyDaylight() must be true.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 6, day: 21, hour: 12)
        guard let date = cal.date(from: comps) else { XCTFail(); return }

        let calc = SolarCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0.0),
            date: date,
            timeZone: .current
        )
        // sunrise/sunset nil for midnight sun, but isCurrentlyDaylight returns true
        XCTAssertTrue(calc.isCurrentlyDaylight(), "89°N in June is midnight sun → always daylight")
    }
}
