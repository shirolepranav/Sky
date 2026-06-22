// VerificationService.swift
// Protocol + Phase 7 stub for the outdoor verification pipeline.
// Tech Spec §8.5 — Phases 8/9 replace StubVerificationService internals
// with real sensor fusion and Vision analysis; no call site changes needed.

import Foundation

enum VerificationResult {
    case success
    case failure(FailureReason)
}

protocol VerificationService {
    /// Analyze the recorded video and return a verification decision.
    /// Implementations must delete `videoURL` before returning.
    func analyze(videoURL: URL) async -> VerificationResult
}

// MARK: - Phase 7 stub

final class StubVerificationService: VerificationService {
    func analyze(videoURL: URL) async -> VerificationResult {
        try? await Task.sleep(for: .seconds(2.5))
        try? FileManager.default.removeItem(at: videoURL)
        return .success
    }
}
