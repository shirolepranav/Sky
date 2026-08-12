// DepthFrameMetrics.swift
// SPIKE — pure aggregation of a single depth buffer into scalars we can compare
// across scenes. Measures whether "sky returns no depth, a ceiling returns ~2–3 m"
// actually separates outdoor-at-night from indoor-at-night.
// Companion to SkyPixelCounter, whose HSV thresholds return ~0 in darkness.
//
// ⚠️ DEBUG ONLY. Nothing here is wired into VerificationDecisionEngine and no user
// outcome depends on it. It exists to produce numbers, not verdicts.
//
// Deliberately pure and free of AVCaptureSession so it is unit-testable against a
// synthesised CVPixelBuffer on the Simulator — see SkyTests/DepthFrameMetricsTests.

#if DEBUG
import CoreVideo
import Foundation

enum DepthRegion: String, CaseIterable {
    case full, top, bottom, left, right
}

/// Scalars derived from one depth frame. All fractions are 0...1.
struct DepthFrameMetrics: Equatable {

    /// Fraction of pixels reading "far or unknown" — the sky candidate signal.
    /// Keyed by region because the physical claim ("sky is up") is about world space
    /// while the buffer is in sensor space, and the user is pitching the phone
    /// skyward per the recording prompts. Measure all five, decide the mapping later.
    var farOrUnknown: [DepthRegion: Double] = [:]

    /// Fraction of pixels carrying a finite, non-zero reading.
    var validFraction: Double = 0

    /// The two "unknown" mechanisms, kept apart on purpose: disparity formats yield 0
    /// for infinite distance but NaN for a failed stereo match, and it is not
    /// established which one LiDAR no-return produces. Measure, don't assume.
    var nanFraction: Double = 0
    var zeroFraction: Double = 0

    /// Distribution of what was actually measured. Meaningless in absolute terms on
    /// `.relative`-accuracy devices — compare shape, not metres.
    var medianValid: Double = 0
    var p90Valid: Double = 0

    var pixelCount: Int = 0
    var width: Int = 0
    var height: Int = 0

    /// Log-spaced buckets over valid readings, plus explicit NaN and zero buckets.
    var histogram: [Int] = []

    static let histogramBuckets = 16

    /// Non-optional accessor — an absent region reads as 0 rather than nil, which keeps
    /// both the HUD formatting and the test assertions free of optional handling.
    func far(_ region: DepthRegion) -> Double { farOrUnknown[region] ?? 0 }
}

enum DepthMetricsCalculator {

    /// Readings beyond this are treated as "far" — past LiDAR's useful range, so
    /// indistinguishable from no return.
    static let farThresholdMeters: Double = 8.0

    /// Disparity is inverse depth; below this is effectively infinite distance.
    static let epsilonDisparity: Double = 1.0 / farThresholdMeters

    /// Aggregates `buffer`. `isDisparity` selects the interpretation of the values —
    /// pass `true` for kCVPixelFormatType_Disparity*, `false` for Depth* (metres).
    ///
    /// Depth buffers are small (typically 320×240–640×480), so every pixel is read;
    /// there is no need for SkyPixelCounter's every-4th-pixel subsampling.
    static func metrics(from buffer: CVPixelBuffer, isDisparity: Bool) -> DepthFrameMetrics {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let format = CVPixelBufferGetPixelFormatType(buffer)

        var result = DepthFrameMetrics()
        result.width = width
        result.height = height
        result.pixelCount = width * height

        guard let base = CVPixelBufferGetBaseAddress(buffer), width > 0, height > 0 else {
            return result
        }

        let is16Bit = (format == kCVPixelFormatType_DepthFloat16
                       || format == kCVPixelFormatType_DisparityFloat16)

        var validValues: [Double] = []
        validValues.reserveCapacity(width * height / 4)

        var nanCount = 0
        var zeroCount = 0
        var regionFar = [DepthRegion: Int]()
        var regionTotal = [DepthRegion: Int]()

        for row in 0..<height {
            let rowBase = base.advanced(by: row * rowBytes)
            for col in 0..<width {
                let value: Double
                if is16Bit {
                    let raw = rowBase.loadUnaligned(fromByteOffset: col * 2, as: Float16.self)
                    value = Double(raw)
                } else {
                    let raw = rowBase.loadUnaligned(fromByteOffset: col * 4, as: Float32.self)
                    value = Double(raw)
                }

                let isNaN = value.isNaN || value.isInfinite
                let isZero = !isNaN && value == 0
                if isNaN { nanCount += 1 }
                if isZero { zeroCount += 1 }

                let isFar: Bool
                if isNaN || isZero {
                    isFar = true
                } else if isDisparity {
                    isFar = value < epsilonDisparity
                } else {
                    isFar = value > farThresholdMeters
                }

                if !isNaN && !isZero { validValues.append(value) }

                for region in regions(forRow: row, col: col, width: width, height: height) {
                    regionTotal[region, default: 0] += 1
                    if isFar { regionFar[region, default: 0] += 1 }
                }
            }
        }

        for region in DepthRegion.allCases {
            let total = regionTotal[region] ?? 0
            result.farOrUnknown[region] = total > 0
                ? Double(regionFar[region] ?? 0) / Double(total)
                : 0
        }

        let pixels = Double(width * height)
        result.nanFraction = Double(nanCount) / pixels
        result.zeroFraction = Double(zeroCount) / pixels
        result.validFraction = Double(validValues.count) / pixels

        if !validValues.isEmpty {
            let sorted = validValues.sorted()
            result.medianValid = sorted[sorted.count / 2]
            result.p90Valid = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
            result.histogram = histogram(of: sorted, nanCount: nanCount, zeroCount: zeroCount)
        } else {
            result.histogram = Array(repeating: 0, count: DepthFrameMetrics.histogramBuckets)
                + [nanCount, zeroCount]
        }

        return result
    }

    /// Which regions a pixel belongs to. Every pixel is in `.full`; edge thirds
    /// overlap in the corners, which is fine — each region is normalised separately.
    private static func regions(forRow row: Int, col: Int, width: Int, height: Int) -> [DepthRegion] {
        var out: [DepthRegion] = [.full]
        if row < height / 3 { out.append(.top) }
        if row >= height - height / 3 { out.append(.bottom) }
        if col < width / 3 { out.append(.left) }
        if col >= width - width / 3 { out.append(.right) }
        return out
    }

    /// 16 log-spaced buckets over the valid range, then NaN and zero counts appended.
    private static func histogram(of sortedValues: [Double], nanCount: Int, zeroCount: Int) -> [Int] {
        var buckets = Array(repeating: 0, count: DepthFrameMetrics.histogramBuckets)
        guard let lo = sortedValues.first, let hi = sortedValues.last, hi > lo else {
            buckets[0] = sortedValues.count
            return buckets + [nanCount, zeroCount]
        }
        let logLo = log(max(lo, 1e-6))
        let logHi = log(hi)
        for v in sortedValues {
            let t = (log(max(v, 1e-6)) - logLo) / (logHi - logLo)
            let index = min(DepthFrameMetrics.histogramBuckets - 1,
                            max(0, Int(t * Double(DepthFrameMetrics.histogramBuckets))))
            buckets[index] += 1
        }
        return buckets + [nanCount, zeroCount]
    }
}
#endif
