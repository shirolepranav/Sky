// VerificationService.swift
// Protocol + Phase 7 stub for the outdoor verification pipeline.
// Tech Spec §8.5. Phase 8 adds VerificationInput (video URL + SensorReading).
// Phase 9 will add frameAnalysis to VerificationInput.
// Phase 10 replaces StubVerificationService with the real decision engine.
// No call-site changes are needed beyond Phase 8.

import Foundation

// MARK: - Input

/// All inputs consumed by the verification pipeline in one composable struct.
/// Phase 9 will add `frameAnalysis: FrameAnalysisResult?` as an optional field.
struct VerificationInput {
    let videoURL: URL
    let sensorReading: SensorReading
}

// MARK: - Result

enum VerificationResult {
    case success
    case failure(FailureReason)
}

// MARK: - Protocol

protocol VerificationService {
    /// Analyze the verification recording. Implementations must delete
    /// `input.videoURL` before returning.
    func analyze(_ input: VerificationInput) async -> VerificationResult
}

// MARK: - Phase 7/8 stub

/// Always passes. Superseded by `RealVerificationService` in Phase 10 and kept
/// only for previews and tests.
///
/// ⚠️ DEBUG ONLY, deliberately. An unconditional `.success` conforming to the
/// same protocol as the real pipeline is the one type that must not be able to
/// reach a shipped build — a single mis-typed injection would turn the outdoor
/// check into a 2.5-second wait. `VerificationProcessingView` takes its service
/// as a required parameter for the same reason: no default, no silent swap.
#if DEBUG
final class StubVerificationService: VerificationService {
    func analyze(_ input: VerificationInput) async -> VerificationResult {
        try? await Task.sleep(for: .seconds(2.5))
        try? FileManager.default.removeItem(at: input.videoURL)
        return .success
    }
}
#endif
