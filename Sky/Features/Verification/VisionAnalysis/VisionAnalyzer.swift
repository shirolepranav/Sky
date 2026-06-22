// VisionAnalyzer.swift
// Samples every 5th frame from the recorded verification video and classifies
// each frame as outdoor/indoor using VNClassifyImageRequest, then measures
// sky-pixel coverage with SkyPixelCounter.
// Tech Spec §8.5, Roadmap Phase 9.
//
// Threading: declared as an actor so Vision handler closures and frame
// iteration can safely accumulate mutable state without explicit locking.

import AVFoundation
import CoreGraphics
import Foundation
import Vision

actor VisionAnalyzer {

    // MARK: - Configuration

    /// VNClassifyImageRequest label identifiers that indicate an outdoor scene.
    private static let outdoorLabels: Set<String> = [
        "outdoor", "sky", "nature", "grass", "tree", "park",
        "beach", "mountain", "field", "forest", "coast",
    ]

    /// Minimum Vision confidence for an outdoor label to count.
    private static let outdoorConfidenceThreshold: Float = 0.30

    /// Downscale frames to this size before classification (faster than 1080p, still accurate).
    private static let frameSize = CGSize(width: 480, height: 270)

    /// Sample every Nth frame. At 30 fps over 30 s: 900 frames ÷ 5 = 180 analysed.
    private static let frameStep: Int = 5

    // MARK: - Public API

    /// Analyses `videoURL` and returns aggregated frame classification results.
    /// Throws if the asset cannot be loaded or no frames can be generated.
    /// Callers must delete `videoURL` themselves (RealVerificationService does this via defer).
    func analyze(videoURL: URL) async throws -> FrameAnalysisResult {
        let asset = AVURLAsset(url: videoURL)

        // Load duration and nominal frame rate asynchronously (iOS 16+ async API).
        let duration = try await asset.load(.duration)
        let tracks   = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw AnalysisError.noVideoTrack
        }
        let nominalFPS = try await videoTrack.load(.nominalFrameRate)
        let fps = nominalFPS > 0 ? Double(nominalFPS) : 30.0

        // Build sample times: every `frameStep` frames across the video.
        let totalFrames = Int(duration.seconds * fps)
        guard totalFrames > 0 else { throw AnalysisError.emptyVideo }

        let step = VisionAnalyzer.frameStep
        let sampleTimes: [CMTime] = stride(from: 0, to: totalFrames, by: step).map { frameIndex in
            CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
        }

        // Set up image generator.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = VisionAnalyzer.frameSize
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: CMTimeScale(fps))
        generator.requestedTimeToleranceAfter  = CMTime(value: 1, timescale: CMTimeScale(fps))

        // Iterate frames asynchronously.
        // AVAssetImageGenerator.images(for:) returns an AsyncSequence whose
        // Element is (requestedTime: CMTime, image: CGImage, actualTime: CMTime).
        // The iterator can throw for individual frames; we skip errors and continue.
        var outdoorCount = 0
        var maxSkyPercent = 0.0
        var analyzed = 0

        // AVAssetImageGenerator.Images.Element: next() returns nil when exhausted (does not throw).
        // frame.image is a throwing property — skip frames that fail to decode.
        var frameIterator = generator.images(for: sampleTimes).makeAsyncIterator()
        while let frame = await frameIterator.next() {
            guard let cgImage = try? frame.image else { continue }
            analyzed += 1

            if classifyOutdoor(cgImage) { outdoorCount += 1 }
            let skyPct = SkyPixelCounter.skyPercent(in: cgImage)
            if skyPct > maxSkyPercent { maxSkyPercent = skyPct }
        }

        guard analyzed > 0 else { throw AnalysisError.noFramesGenerated }

        return FrameAnalysisResult(
            outdoorFrameRatio: Double(outdoorCount) / Double(analyzed),
            maxSkyPixelPercent: maxSkyPercent,
            analyzedFrameCount: analyzed
        )
    }

    // MARK: - Private: Vision classification

    /// Returns `true` if any top-confidence label from `VNClassifyImageRequest` matches
    /// one of the outdoor identifier strings with confidence ≥ the threshold.
    private func classifyOutdoor(_ image: CGImage) -> Bool {
        var isOutdoor = false
        let threshold = VisionAnalyzer.outdoorConfidenceThreshold
        let labels    = VisionAnalyzer.outdoorLabels
        let request = VNClassifyImageRequest { request, _ in
            guard let observations = request.results as? [VNClassificationObservation] else { return }
            for obs in observations {
                guard obs.confidence >= threshold else { break } // sorted descending
                if labels.contains(obs.identifier) {
                    isOutdoor = true
                    return
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        return isOutdoor
    }

    // MARK: - Errors

    enum AnalysisError: Error {
        case noVideoTrack
        case emptyVideo
        case noFramesGenerated
    }
}
