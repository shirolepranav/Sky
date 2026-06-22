// FrameAnalysisResult.swift
// Aggregated per-frame vision outputs consumed by VerificationDecisionEngine.
// Produced by VisionAnalyzer; defined here to break import cycles.
// Tech Spec §8.5, Roadmap Phase 9/10.

import Foundation

struct FrameAnalysisResult: Equatable {
    /// Fraction of analyzed frames where any outdoor-related label scored ≥ 0.30 confidence.
    let outdoorFrameRatio: Double
    /// Highest sky-pixel percentage observed across all analyzed frames.
    let maxSkyPixelPercent: Double
    /// Number of frames actually analyzed (< total frames due to every-5th sampling).
    let analyzedFrameCount: Int

    /// Sentinel used when vision analysis could not run (e.g., simulator, unit tests).
    static let zero = FrameAnalysisResult(
        outdoorFrameRatio: 0,
        maxSkyPixelPercent: 0,
        analyzedFrameCount: 0
    )
}
