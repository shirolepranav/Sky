// FailureReason.swift
// Verification failure cases with user-facing copy.
// Sky_App_Workflow.md §Part 2 S-VER-07 copy table; raw values match
// Tech Spec §8.5 decision engine identifiers so Phase 8/9 can produce
// them directly without a translation layer.

import Foundation

enum FailureReason: String, CaseIterable, Hashable {
    case gpsSpoofingDetected
    case outsideDaylightWindow
    case poorGPSSignal
    case notEnoughMovement
    case notBrightEnough
    case sceneNotOutdoor
    case noSkyVisible
    case unexpectedError

    var title: String {
        switch self {
        case .gpsSpoofingDetected:   return "Hmm, that doesn't add up."
        case .outsideDaylightWindow:  return "It's dark out."
        case .poorGPSSignal:          return "Couldn't find you."
        case .notEnoughMovement:      return "Not enough walking."
        case .notBrightEnough:        return "Too dim."
        case .sceneNotOutdoor:        return "That didn't look outdoor."
        case .noSkyVisible:           return "Show some sky."
        case .unexpectedError:        return "Something went wrong."
        }
    }

    var body: String {
        switch self {
        case .gpsSpoofingDetected:
            return "Sky couldn't trust the GPS reading. If you've got a location-spoofing tool installed, turn it off and try again."
        case .outsideDaylightWindow:
            return "Sky uses daylight as part of the check. Try again after sunrise, or turn on Night Mode in Settings."
        case .poorGPSSignal:
            return "GPS was too fuzzy. Try moving away from buildings or being more in the open."
        case .notEnoughMovement:
            return "Take a few real steps while you record. It only needs to be a short walk."
        case .notBrightEnough:
            return "Sky needs daylight on the camera. Try somewhere brighter."
        case .sceneNotOutdoor:
            return "The camera mostly saw indoor scenes. Try again outside, ideally with sky in view."
        case .noSkyVisible:
            return "Sky needs at least a glimpse of sky in the video. Tilt up for a few seconds and try again."
        case .unexpectedError:
            return "Try again — if it keeps happening, restart Sky."
        }
    }
}
