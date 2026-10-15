// FailureReason.swift
// Verification failure cases with user-facing copy.
// Sky_App_Workflow.md §Part 2 S-VER-07 copy table; DAILY_LOCK_PLAN.md Phase E.
// Brand voice (PRD §7): kind and specific — say what to do next, never scold.

import Foundation

enum FailureReason: String, CaseIterable, Hashable, Error {
    case gpsSpoofingDetected
    case poorGPSSignal
    case motionAccessNeeded
    case notEnoughSteps
    case sceneNotOutdoor
    case unexpectedError

    var title: String {
        switch self {
        case .gpsSpoofingDetected: return "Hmm, that doesn't add up."
        case .poorGPSSignal:       return "Couldn't find you."
        case .motionAccessNeeded:  return "Sky can't count your steps."
        case .notEnoughSteps:      return "A few more steps."
        case .sceneNotOutdoor:     return "Show Nimbus the sky."
        case .unexpectedError:     return "Something went wrong."
        }
    }

    var body: String {
        switch self {
        case .gpsSpoofingDetected:
            return "Sky couldn't trust the GPS reading. If you've got a location-spoofing tool installed, turn it off and try again."
        case .poorGPSSignal:
            return "GPS was too fuzzy. Step away from buildings into the open and try again."
        case .motionAccessNeeded:
            return "Turn on Motion & Fitness for Sky in the Settings app, then try again."
        case .notEnoughSteps:
            return "Nimbus wants a little walk ☁ About \(VerificationThresholds.minRecentSteps) steps, then record again."
        case .sceneNotOutdoor:
            return "The camera didn't see much sky. Start at the ground and tilt up until the sky fills the frame."
        case .unexpectedError:
            return "Try again — if it keeps happening, restart Sky."
        }
    }
}
