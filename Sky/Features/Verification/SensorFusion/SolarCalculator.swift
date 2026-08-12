// SolarCalculator.swift
// Pure-Swift NOAA ESRL simplified solar position algorithm.
// Accurate to ±2 minutes at latitudes 0–65°; handles polar night / midnight-sun edge cases.
// Queryable at any zenith angle — `officialZenith` for true sunrise/sunset, and
// `civilTwilightZenith` for the wider window verification is actually allowed in.
// No third-party dependencies. Tech Spec §8, Roadmap Phase 8.
// Reference: NOAA Solar Equations (https://gml.noaa.gov/grad/solcalc/solareqns.PDF)

import CoreLocation
import Foundation

struct SolarCalculator {
    let coordinate: CLLocationCoordinate2D
    /// The calendar date for which to compute sunrise/sunset (time-of-day is ignored).
    let date: Date
    let timeZone: TimeZone

    // MARK: - Zenith conventions

    /// Zenith angle for true sunrise/sunset: 90° plus the standard 0.833° allowance
    /// for atmospheric refraction and the sun's semi-diameter.
    static let officialZenith: Double = 90.833

    /// Zenith angle for civil twilight — the sun 6° below the horizon. There is still
    /// ample light to see by, and for the camera to work, which is why the *verification*
    /// window uses this rather than `officialZenith`: at high latitudes in winter the
    /// true-sunset window is punishingly narrow (Helsinki on 21 Dec gets under six hours
    /// of daylight, entirely inside work and school hours).
    static let civilTwilightZenith: Double = 96.0

    // MARK: - Public API

    /// Sunrise time on `date` at `coordinate`, or `nil` for polar night / midnight sun.
    func sunrise() -> Date? { sunriseSunsetDates(zenith: Self.officialZenith)?.sunrise }

    /// Sunset time on `date` at `coordinate`, or `nil` for polar night / midnight sun.
    func sunset() -> Date? { sunriseSunsetDates(zenith: Self.officialZenith)?.sunset }

    /// `true` when `date` falls between true sunrise and true sunset.
    /// Polar night → false. Midnight sun → true. No GPS fix → false.
    func isCurrentlyDaylight() -> Bool { isWithin(zenith: Self.officialZenith) }

    /// `true` when `date` falls inside the window verification is allowed in — civil
    /// twilight, which is wider than `isCurrentlyDaylight()` at every latitude and
    /// markedly wider at high ones. This is the gate `SensorRecorder` applies;
    /// `isCurrentlyDaylight()` keeps true sunrise/sunset semantics for anything else.
    func isWithinVerificationWindow() -> Bool { isWithin(zenith: Self.civilTwilightZenith) }

    // MARK: - Internal (exposed for unit tests)

    /// Returns (sunriseUTC, sunsetUTC) on the date in UTC minutes-from-midnight, or nil
    /// when the sun never crosses `zenith` on this date (polar night / midnight sun).
    func utcMinutes(zenith: Double = SolarCalculator.officialZenith) -> (sunrise: Double, sunset: Double)? {
        let geo = solarGeometry()
        let cosHA = hourAngleCosine(zenith: zenith, geometry: geo)
        guard abs(cosHA) <= 1.0 else { return nil }

        let ha = deg(acos(cosHA))
        let noon = 720.0 - 4.0 * coordinate.longitude - geo.equationOfTime
        return (sunrise: noon - 4.0 * ha, sunset: noon + 4.0 * ha)
    }

    // MARK: - Private helpers

    /// Date-dependent solar quantities, independent of zenith. Computed once and shared
    /// by every query so the geometry block isn't duplicated per convention.
    private struct SolarGeometry {
        let declination: Double
        let equationOfTime: Double
    }

    private func solarGeometry() -> SolarGeometry {
        let t = julianCentury(jd: julianDate())

        let l0 = geomMeanLongSun(t: t)
        let m  = geomMeanAnomalySun(t: t)
        let e  = orbitEccentricity(t: t)
        let c  = sunEquationOfCenter(t: t, m: m)
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(rad(omega))
        let e0 = meanObliquityOfEcliptic(t: t)
        let eps = e0 + 0.00256 * cos(rad(omega))

        return SolarGeometry(
            declination: sunDeclination(eps: eps, lambda: lambda),
            equationOfTime: equationOfTime(t: t, eps: eps, l0: l0, m: m, e: e)
        )
    }

    /// Cosine of the hour angle at which the sun reaches `zenith`.
    /// `< -1` → the sun never descends that far (midnight sun / all-night twilight).
    /// `>  1` → it never climbs that high (polar night).
    private func hourAngleCosine(zenith: Double, geometry: SolarGeometry) -> Double {
        let lat  = coordinate.latitude
        let decl = geometry.declination
        return cos(rad(zenith)) / (cos(rad(lat)) * cos(rad(decl)))
               - tan(rad(lat)) * tan(rad(decl))
    }

    private func sunriseSunsetDates(zenith: Double) -> (sunrise: Date, sunset: Date)? {
        guard let (riseMin, setMin) = utcMinutes(zenith: zenith) else { return nil }
        guard let rise = utcDate(minutes: riseMin),
              let set  = utcDate(minutes: setMin) else { return nil }
        return (rise, set)
    }

    /// Shared implementation behind both window queries.
    private func isWithin(zenith: Double) -> Bool {
        guard let (rise, set) = sunriseSunsetDates(zenith: zenith) else {
            // nil only at polar extremes. cosHA < -1 means the sun stays above this
            // zenith for the whole day → we are inside the window, not outside it.
            return hourAngleCosine(zenith: zenith, geometry: solarGeometry()) < -1.0
        }
        return date >= rise && date <= set
    }

    // MARK: Julian date

    private func julianDate() -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let y = Double(c.year ?? 2000)
        let mo = Double(c.month ?? 1)
        let d = Double(c.day ?? 1)
        let ut = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60.0 + Double(c.second ?? 0) / 3600.0

        // Standard Julian Day formula
        let a = floor((14.0 - mo) / 12.0)
        let yr = y + 4800.0 - a
        let mn = mo + 12.0 * a - 3.0
        var jdn = d + floor((153.0 * mn + 2.0) / 5.0) + 365.0 * yr
                  + floor(yr / 4.0) - floor(yr / 100.0) + floor(yr / 400.0) - 32045.0
        jdn += ut / 24.0 - 0.5
        return jdn
    }

    private func julianCentury(jd: Double) -> Double {
        (jd - 2_451_545.0) / 36_525.0
    }

    // MARK: Solar geometry (all angles in degrees; convert to radians for trig calls)

    private func geomMeanLongSun(t: Double) -> Double {
        let l = 280.46646 + t * (36_000.76983 + t * 0.0003032)
        return l.truncatingRemainder(dividingBy: 360.0) + (l < 0 ? 360.0 : 0.0)
    }

    private func geomMeanAnomalySun(t: Double) -> Double {
        357.52911 + t * (35_999.05029 - 0.0001537 * t)
    }

    private func orbitEccentricity(t: Double) -> Double {
        0.016_708_634 - t * (0.000_042_037 + 0.000_000_1267 * t)
    }

    private func sunEquationOfCenter(t: Double, m: Double) -> Double {
        sin(rad(m)) * (1.914_602 - t * (0.004_817 + 0.000_014 * t))
        + sin(rad(2 * m)) * (0.019_993 - 0.000_101 * t)
        + sin(rad(3 * m)) * 0.000_289
    }

    private func meanObliquityOfEcliptic(t: Double) -> Double {
        let seconds = 21.448 - t * (46.8150 + t * (0.000_59 - t * 0.001_813))
        return 23.0 + (26.0 + seconds / 60.0) / 60.0
    }

    private func sunDeclination(eps: Double, lambda: Double) -> Double {
        deg(asin(sin(rad(eps)) * sin(rad(lambda))))
    }

    private func equationOfTime(t: Double, eps: Double, l0: Double, m: Double, e: Double) -> Double {
        let y = pow(tan(rad(eps / 2.0)), 2)
        let eqT = y * sin(rad(2 * l0))
                  - 2 * e * sin(rad(m))
                  + 4 * e * y * sin(rad(m)) * cos(rad(2 * l0))
                  - 0.5 * pow(y, 2) * sin(rad(4 * l0))
                  - 1.25 * pow(e, 2) * sin(rad(2 * m))
        return deg(eqT) * 4  // convert radians → degrees → minutes (× 4 min/deg)
    }

    // MARK: Date conversion

    /// Convert UTC minutes-from-midnight (on the reference calendar date) to a Date.
    private func utcDate(minutes: Double) -> Date? {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utcCal.startOfDay(for: date)
        return midnight.addingTimeInterval(minutes * 60.0)
    }

    // MARK: Convenience converters

    @inline(__always) private func rad(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    @inline(__always) private func deg(_ radians: Double) -> Double { radians * 180.0 / .pi }
}
