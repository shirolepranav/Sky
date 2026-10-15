// VerificationDecisionEngine.swift
// Pure, stateless evaluation of the three verification checks
// (DAILY_LOCK_PLAN.md Phase E; Tech Spec §8.5). Takes a SensorReading and a
// FrameAnalysisResult and returns the first failing condition, or .success.
//
// Order: GPS (spoofed, then fuzzy) → steps → outdoor scene. GPS comes first
// because "no fix" is the most common environmental failure and its message is
// the most actionable. The scene check only runs in daylight: Vision can't see a
// night sky, so after civil dusk GPS + steps decide alone.

import Foundation

struct VerificationDecisionEngine {

    func evaluate(sensor: SensorReading, frame: FrameAnalysisResult) -> Result<Void, FailureReason> {
        // 1. GPS — spoofing is a hard block; .infinity (no fix) fails accuracy.
        if sensor.gpsSpoofed {
            return .failure(.gpsSpoofingDetected)
        }
        if sensor.gpsAccuracyAtBest > VerificationThresholds.maxAcceptableGPSError {
            return .failure(.poorGPSSignal)
        }

        // 2. Steps — nil means this device can't count steps; the check is waived.
        if sensor.motionDenied {
            return .failure(.motionAccessNeeded)
        }
        if let steps = sensor.recentSteps, steps < VerificationThresholds.minRecentSteps {
            return .failure(.notEnoughSteps)
        }

        // 3. Outdoor scene — daylight only.
        if sensor.isDaylight {
            if frame.outdoorFrameRatio < VerificationThresholds.minOutdoorFrameRatio
                || frame.maxSkyPixelPercent < VerificationThresholds.minSkyPixelPercent {
                return .failure(.sceneNotOutdoor)
            }
        }

        return .success(())
    }
}
