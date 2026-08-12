// VerificationDecisionEngine.swift
// Pure, stateless evaluation of every sensor and vision signal.
// Takes a SensorReading (Phase 8) and a FrameAnalysisResult (Phase 9) and
// returns the first failing condition, or .success(()) when all pass.
// Tech Spec §8.5, Roadmap Phase 10.
//
// Checks run in priority order — the most definitive signal (GPS spoofing) first,
// the most context-dependent (sky pixels) last.
//
// GPS *validity* is established before the daylight check, and the order matters:
// `sunriseSunsetCheckPassed` is false both when it is genuinely dark and when no
// location fix ever arrived (SensorRecorder.sunriseSunsetCheck can't run without a
// coordinate). Since `bestGPSAccuracy()` returns .infinity for an empty sample set,
// testing accuracy first routes the no-fix case to .poorGPSSignal — otherwise a user
// whose GPS never locked was told "It's dark out." at noon. After this ordering,
// a false `sunriseSunsetCheckPassed` means only "genuinely dark" (polar night
// included, where that message is correct).

import Foundation

struct VerificationDecisionEngine {

    /// - Parameter nightModeEnabled: when true, the daylight (sunrise/sunset)
    ///   check is bypassed (S-SET-05). Every other signal still applies.
    func evaluate(
        sensor: SensorReading,
        frame: FrameAnalysisResult,
        nightModeEnabled: Bool = false
    ) -> Result<Void, FailureReason> {
        // 1. GPS spoofing — hard block regardless of all other signals.
        if sensor.gpsSpoofed {
            return .failure(.gpsSpoofingDetected)
        }

        // 2. GPS accuracy too poor to trust location — also catches "no fix at all",
        //    which surfaces as .infinity. Must precede the daylight check (see header).
        if sensor.gpsAccuracyAtBest > VerificationThresholds.maxAcceptableGPSError {
            return .failure(.poorGPSSignal)
        }

        // 3. Outside the verification daylight window — civil-twilight check from
        //    SolarCalculator. Night Mode (opt-in) waives this one check only.
        if !sensor.sunriseSunsetCheckPassed && !nightModeEnabled {
            return .failure(.outsideDaylightWindow)
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
