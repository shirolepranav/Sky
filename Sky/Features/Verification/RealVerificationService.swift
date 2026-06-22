// RealVerificationService.swift
// Production implementation of VerificationService.
// Replaces StubVerificationService as the default in VerificationProcessingView.
// Coordinates: VisionAnalyzer → FrameAnalysisResult → VerificationDecisionEngine → result.
// The video file is always deleted via defer, regardless of outcome.
// Tech Spec §8.5, Roadmap Phase 10.

import Foundation

final class RealVerificationService: VerificationService {

    func analyze(_ input: VerificationInput) async -> VerificationResult {
        // Guarantee cleanup even if analysis throws or returns early.
        defer { try? FileManager.default.removeItem(at: input.videoURL) }

        do {
            let frameResult = try await VisionAnalyzer().analyze(videoURL: input.videoURL)
            let decision    = VerificationDecisionEngine().evaluate(
                sensor: input.sensorReading,
                frame:  frameResult
            )
            switch decision {
            case .success:           return .success
            case .failure(let reason): return .failure(reason)
            }
        } catch {
            return .failure(.unexpectedError)
        }
    }
}
