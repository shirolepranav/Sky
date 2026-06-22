// VerificationThresholds.swift
// Single tunable source for all verification signal thresholds.
// Tech Spec §8.5. Phase 8 defines them; Phase 10 (VerificationDecisionEngine) reads them.
// Re-measure against real-world recordings in 5+ environments before launch (Roadmap Phase 10).
// Never duplicate these values elsewhere.

import CoreLocation

enum VerificationThresholds {
    // GPS
    static let maxAcceptableGPSError: CLLocationAccuracy = 25.0  // metres — above this = likely indoors
    static let minHorizontalSpeed: Double = 0.3                   // m/s  — below = not walking
    static let minAltitudeChange: Double  = 0.5                   // metres — combined with speed check

    // Ambient light (camera exposureTargetOffset)
    static let minExposureBias: Float = -1.0                      // below this = too dim

    // Vision (used in Phases 9 and 10 — defined here for central ownership)
    static let minOutdoorFrameRatio: Double = 0.8                 // 80 % of frames must score outdoor
    static let minSkyPixelPercent: Double   = 0.15                // at least one frame ≥ 15 % sky pixels
}
