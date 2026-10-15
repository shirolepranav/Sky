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
    /// JPEG of the frame with the most sky, at share resolution — kept as
    /// "today's sky" on a pass (SkyPhotoStore, DAILY_LOCK_PLAN.md Phase F).
    var bestFrameJPEG: Data? = nil

    /// Sentinel used when vision analysis could not run (e.g., simulator, unit tests).
    static let zero = FrameAnalysisResult(
        outdoorFrameRatio: 0,
        maxSkyPixelPercent: 0,
        analyzedFrameCount: 0
    )
}
