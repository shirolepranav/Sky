// SensorReading.swift
// Aggregated sensor snapshot from an outdoor verification.
// Tech Spec §8.4; DAILY_LOCK_PLAN.md Phase E. Produced by SensorRecorder,
// consumed by VerificationDecisionEngine.

import CoreLocation
import Foundation

struct SensorReading: Equatable, Hashable {
    /// Smallest horizontalAccuracy value seen (smaller = better). .infinity = no fix.
    let gpsAccuracyAtBest: CLLocationAccuracy
    /// Local time when recording started.
    let timeOfDay: Date
    /// True if any GPS sample carried an accessory/simulated-by-software flag.
    let gpsSpoofed: Bool
    /// True between civil dawn and civil dusk at the recorded location. When false
    /// the camera checks are waived (they can't see a night sky).
    let isDaylight: Bool
    /// Steps in the `stepWindowSeconds` before recording ended, or nil when this
    /// device can't count steps at all (the check is then waived).
    let recentSteps: Int?
    /// True when the user has denied Motion & Fitness access.
    let motionDenied: Bool
    /// Best GPS location rounded to 0.01° as "lat_lng", used for the Wanderer badge.
    let bestLocationTag: String?

    init(
        gpsAccuracyAtBest: CLLocationAccuracy,
        timeOfDay: Date = Date(),
        gpsSpoofed: Bool = false,
        isDaylight: Bool,
        recentSteps: Int?,
        motionDenied: Bool = false,
        bestLocationTag: String? = nil
    ) {
        self.gpsAccuracyAtBest = gpsAccuracyAtBest
        self.timeOfDay         = timeOfDay
        self.gpsSpoofed        = gpsSpoofed
        self.isDaylight        = isDaylight
        self.recentSteps       = recentSteps
        self.motionDenied      = motionDenied
        self.bestLocationTag   = bestLocationTag
    }

    /// Zero-signal sentinel used when sensors are unavailable (simulator, mocks).
    static let unavailable = SensorReading(
        gpsAccuracyAtBest: .infinity,
        isDaylight: false,
        recentSteps: 0
    )
}
