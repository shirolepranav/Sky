// SensorReading.swift
// Aggregated sensor snapshot from a 30-second outdoor verification recording.
// Tech Spec §8.4. Produced by SensorRecorder, consumed by VerificationProcessingView
// and (Phase 10) VerificationDecisionEngine.
//
// Conforms to Equatable + Hashable so it can be embedded in RecordingState.finished
// (needs Equatable) and VerificationStep.processing (needs Hashable).

import CoreLocation
import Foundation

struct SensorReading: Equatable, Hashable {
    /// Smallest horizontalAccuracy value seen during recording (smaller = better signal).
    let gpsAccuracyAtBest: CLLocationAccuracy
    /// Highest speed observed, in m/s. Uses CLLocation.speed (Kalman-filtered) when available.
    let maxHorizontalSpeed: Double
    /// |max − min| relative altitude over the recording window, in metres.
    let altitudeChangeMeters: Double
    /// Median camera exposureTargetOffset — negative = underexposed/dark, 0 = correct.
    let medianExposureBias: Float
    /// Local time when recording started — used for sunrise/sunset check.
    let timeOfDay: Date
    /// True if any GPS sample carried an accessory/simulated-by-software flag (spoof detected).
    let gpsSpoofed: Bool
    /// True if timeOfDay falls between sunrise and sunset at the recorded location.
    let sunriseSunsetCheckPassed: Bool

    /// Zero-signal sentinel used when sensors are unavailable (simulator, mock tests).
    static let unavailable = SensorReading(
        gpsAccuracyAtBest: .infinity,
        maxHorizontalSpeed: 0,
        altitudeChangeMeters: 0,
        medianExposureBias: 0,
        timeOfDay: Date(),
        gpsSpoofed: false,
        sunriseSunsetCheckPassed: false
    )
}
