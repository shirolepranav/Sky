// DepthFrameMetricsTests.swift
// SPIKE tests — pins the pure aggregation in DepthFrameMetrics against synthesised
// depth buffers. Runs on the Simulator; no camera or depth hardware involved.
//
// Worth noting: VisionAnalyzer and SkyPixelCounter currently have zero tests, so this
// establishes the pure-function-plus-tests shape any future check-7 replacement needs.

#if DEBUG
import CoreVideo
import XCTest
@testable import Sky

final class DepthFrameMetricsTests: XCTestCase {

    // MARK: - Buffer synthesis

    /// Builds a Float32 depth buffer, filling each pixel from `value(row:col:)`.
    private func makeBuffer(
        width: Int = 24,
        height: Int = 24,
        format: OSType = kCVPixelFormatType_DepthFloat32,
        value: (Int, Int) -> Float32
    ) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, nil, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            fatalError("could not allocate test depth buffer (status \(status))")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<height {
            let rowBase = base.advanced(by: row * rowBytes)
            for col in 0..<width {
                rowBase.storeBytes(of: value(row, col), toByteOffset: col * 4, as: Float32.self)
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    // MARK: - The two extremes

    /// The sky case: nothing returns a reading at all.
    func testAllNaNIsEntirelyFarOrUnknown() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in Float32.nan }, isDisparity: false
        )
        XCTAssertEqual(m.far(.full), 1.0)
        XCTAssertEqual(m.nanFraction, 1.0)
        XCTAssertEqual(m.zeroFraction, 0.0)
        XCTAssertEqual(m.validFraction, 0.0)
    }

    /// The ceiling case: a uniform close surface, well inside LiDAR range.
    func testUniformCeilingDepthIsEntirelyNear() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in 2.5 }, isDisparity: false
        )
        XCTAssertEqual(m.far(.full), 0.0)
        XCTAssertEqual(m.validFraction, 1.0)
        XCTAssertEqual(m.medianValid, 2.5, accuracy: 0.001)
        XCTAssertEqual(m.p90Valid, 2.5, accuracy: 0.001)
    }

    /// Separation between the two extremes is the entire premise of the spike.
    func testSkyAndCeilingSeparateCompletely() {
        let sky = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in Float32.nan }, isDisparity: false
        )
        let ceiling = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in 2.5 }, isDisparity: false
        )
        let gap = sky.far(.full) - ceiling.far(.full)
        XCTAssertEqual(gap, 1.0, "synthetic extremes must separate fully")
    }

    // MARK: - NaN vs zero are counted apart

    /// Both read as "far", but which one a device produces for no-return is unknown,
    /// so they must stay distinguishable in the output.
    func testZeroAndNaNBothCountAsFarButAreReportedSeparately() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer { row, _ in row < 12 ? Float32.nan : 0 }, isDisparity: false
        )
        XCTAssertEqual(m.far(.full), 1.0, "zero and NaN are both 'far or unknown'")
        XCTAssertEqual(m.nanFraction, 0.5, accuracy: 0.01)
        XCTAssertEqual(m.zeroFraction, 0.5, accuracy: 0.01)
    }

    // MARK: - Region splits

    /// The orientation-agnostic part: a half-sky/half-ceiling frame must show the
    /// split in the top/bottom regions rather than only in the full-frame number.
    func testTopHalfSkyShowsInTheTopRegion() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer(height: 24) { row, _ in row < 12 ? Float32.nan : 2.5 },
            isDisparity: false
        )
        XCTAssertEqual(m.far(.full), 0.5, accuracy: 0.01)
        XCTAssertEqual(m.far(.top), 1.0, accuracy: 0.01, "top third is all sky")
        XCTAssertEqual(m.far(.bottom), 0.0, accuracy: 0.01, "bottom third is all ceiling")
    }

    /// Same scene rotated 90° — the signal must survive in left/right instead, which is
    /// why all four edge regions are computed rather than assuming "sky is up".
    func testLeftHalfSkyShowsInTheLeftRegion() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer(width: 24) { _, col in col < 12 ? Float32.nan : 2.5 },
            isDisparity: false
        )
        XCTAssertEqual(m.far(.left), 1.0, accuracy: 0.01)
        XCTAssertEqual(m.far(.right), 0.0, accuracy: 0.01)
    }

    // MARK: - Threshold semantics

    /// Beyond LiDAR's useful range reads the same as no return — the R2 risk in the
    /// plan, where a warehouse ceiling may be indistinguishable from open sky.
    func testBeyondFarThresholdCountsAsFar() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in 12.0 }, isDisparity: false
        )
        XCTAssertEqual(m.far(.full), 1.0, "12 m is past the 8 m far threshold")
        XCTAssertEqual(m.validFraction, 1.0, "…but it is still a valid reading")
    }

    /// Disparity is inverse depth, so the comparison flips direction.
    func testDisparityIsInterpretedAsInverseDepth() {
        let near = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in 0.5 }, isDisparity: true   // 2 m
        )
        let far = DepthMetricsCalculator.metrics(
            from: makeBuffer { _, _ in 0.01 }, isDisparity: true  // 100 m
        )
        XCTAssertEqual(near.far(.full), 0.0, "high disparity is near")
        XCTAssertEqual(far.far(.full), 1.0, "low disparity is far")
    }

    // MARK: - Shape

    func testHistogramCarriesNaNAndZeroBuckets() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer { row, _ in row < 8 ? Float32.nan : (row < 16 ? 0 : 2.5) },
            isDisparity: false
        )
        XCTAssertEqual(m.histogram.count, DepthFrameMetrics.histogramBuckets + 2)
        XCTAssertEqual(m.histogram[DepthFrameMetrics.histogramBuckets], 8 * 24, "NaN bucket")
        XCTAssertEqual(m.histogram[DepthFrameMetrics.histogramBuckets + 1], 8 * 24, "zero bucket")
    }

    func testDimensionsAreReported() {
        let m = DepthMetricsCalculator.metrics(
            from: makeBuffer(width: 32, height: 16) { _, _ in 1.0 }, isDisparity: false
        )
        XCTAssertEqual(m.width, 32)
        XCTAssertEqual(m.height, 16)
        XCTAssertEqual(m.pixelCount, 512)
    }

    func testFloat16BuffersAreDecoded() {
        let m = DepthMetricsCalculator.metrics(
            from: makeFloat16Buffer(value: 2.5), isDisparity: false
        )
        XCTAssertEqual(m.validFraction, 1.0)
        XCTAssertEqual(m.medianValid, 2.5, accuracy: 0.01)
    }

    private func makeFloat16Buffer(value: Float16, width: Int = 16, height: Int = 16) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_DepthFloat16, nil, &buffer)
        guard let buffer else { fatalError("could not allocate Float16 test buffer") }
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<height {
            let rowBase = base.advanced(by: row * rowBytes)
            for col in 0..<width {
                rowBase.storeBytes(of: value, toByteOffset: col * 2, as: Float16.self)
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
#endif
