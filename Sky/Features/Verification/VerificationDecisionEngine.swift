// VerificationDecisionEngine.swift
// Pure, stateless evaluation of every sensor and vision signal.
// Takes a SensorReading (Phase 8) and a FrameAnalysisResult (Phase 9) and
// returns the first failing condition, or .success(()) when all pass.
// Tech Spec §8.5, Roadmap Phase 10.
//
// Checks run in priority order — the most definitive signal (GPS spoofing) first,
// the most context-dependent (sky pixels) last.

import Foundation

struct VerificationDecisionEngine {

    func evaluate(sensor: SensorReading, frame: FrameAnalysisResult) -> Result<Void, FailureReason> {
        // 1. GPS spoofing — hard block regardless of all other signals.
        if sensor.gpsSpoofed {
            return .failure(.gpsSpoofingDetected)
        }

        // 2. Outside daylight window — sunrise/sunset check from SolarCalculator.
        if !sensor.sunriseSunsetCheckPassed {
            return .failure(.outsideDaylightWindow)
        }

        // 3. GPS accuracy too poor to trust location.
        if sensor.gpsAccuracyAtBest > VerificationThresholds.maxAcceptableGPSError {
            return .failure(.poorGPSSignal)
        }

        // 4. Not enough movement — speed OR altitude change must meet threshold
        //    (altitude is the fallback for slow walkers where CL speed is unreliable).
        let hasSufficientSpeed    = sensor.maxHorizontalSpeed    >= VerificationThresholds.minHorizontalSpeed
        let hasSufficientAltitude = sensor.altitudeChangeMeters  >= VerificationThresholds.minAltitudeChange
        if !hasSufficientSpeed && !hasSufficientAltitude {
            return .failure(.notEnoughMovement)
        }

        // 5. Too dim — camera exposure bias below threshold indicates indoor / night lighting.
        if sensor.medianExposureBias < VerificationThresholds.minExposureBias {
            return .failure(.notBrightEnough)
        }

        // 6. Scene not outdoor — too few frames classified as outdoor by Vision.
        if frame.outdoorFrameRatio < VerificationThresholds.minOutdoorFrameRatio {
            return .failure(.sceneNotOutdoor)
        }

        // 7. No sky visible — highest observed sky-pixel fraction below threshold.
        if frame.maxSkyPixelPercent < VerificationThresholds.minSkyPixelPercent {
            return .failure(.noSkyVisible)
        }

        return .success(())
    }
}
