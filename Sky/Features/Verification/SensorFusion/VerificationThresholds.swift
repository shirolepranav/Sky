// VerificationThresholds.swift
// Single tunable source for all verification signal thresholds.
// Tech Spec §8.5; DAILY_LOCK_PLAN.md Phase E (three checks + 5-second clip).
// ⚠️ Placeholders until field-tested: re-measure against real walks in 5+
// environments before launch. Never duplicate these values elsewhere.

import CoreLocation

enum VerificationThresholds {
    // 1. GPS — above this the fix is too fuzzy to trust (likely indoors / no fix).
    static let maxAcceptableGPSError: CLLocationAccuracy = 50.0  // metres

    // 2. Steps — read retroactively from CMPedometer, so the walk happens first.
    static let minRecentSteps = 200
    static let stepWindowSeconds: TimeInterval = 15 * 60

    // 3. Outdoor scene (daylight only — waived after civil dusk).
    static let minOutdoorFrameRatio: Double = 0.6   // 60 % of sampled frames score outdoor
    static let minSkyPixelPercent: Double   = 0.10  // best frame shows ≥ 10 % sky

    /// Recording length. The ground-to-sky tilt fits comfortably in five seconds.
    static let clipSeconds = 5

    /// After the clip stops, how long to keep waiting for a usable GPS fix — a
    /// five-second window is often shorter than a cold fix.
    static let gpsGraceSeconds: TimeInterval = 6
}
