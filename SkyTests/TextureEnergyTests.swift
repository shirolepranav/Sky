// TextureEnergyTests.swift
// SPIKE tests — pins the daylight-independent smoothness signal against synthesised
// images. The key property under test: the measurement must depend on *structure*,
// not on brightness, so a black-but-smooth night sky reads like a blue one.

#if DEBUG
import CoreGraphics
import XCTest
@testable import Sky

final class TextureEnergyTests: XCTestCase {

    // MARK: - Image synthesis

    private func makeImage(
        width: Int = 64,
        height: Int = 64,
        pixel: (Int, Int) -> (UInt8, UInt8, UInt8)
    ) -> CGImage {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for col in 0..<width {
                let (r, g, b) = pixel(row, col)
                let index = (row * width + col) * 4
                data[index] = r
                data[index + 1] = g
                data[index + 2] = b
                data[index + 3] = 255
            }
        }
        let context = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private func flat(_ level: UInt8) -> CGImage {
        makeImage { _, _ in (level, level, level) }
    }

    /// Alternating pixels — a stand-in for the hard edges of vents, beams and fixtures.
    private func checkerboard(light: UInt8 = 200, dark: UInt8 = 40) -> CGImage {
        makeImage { row, col in
            let v = (row + col) % 2 == 0 ? light : dark
            return (v, v, v)
        }
    }

    // MARK: - The core property

    /// Bright flat sky and dark flat sky must measure the same. This is the whole
    /// reason for the signal: SkyPixelCounter fails at night precisely because both
    /// its branches gate on brightness (`v >= 0.35` / `v >= 0.75`).
    func testEnergyIsIndependentOfBrightness() {
        let daySky = TextureEnergy.gradientEnergy(in: flat(200))
        let nightSky = TextureEnergy.gradientEnergy(in: flat(8))
        XCTAssertEqual(daySky, nightSky, accuracy: 0.001,
                       "a smooth surface must read the same bright or dark")
        XCTAssertEqual(nightSky, 0.0, accuracy: 0.001, "flat means zero gradient")
    }

    /// The separation the spike is looking for.
    func testTexturedSurfaceScoresFarAboveSmoothSurface() {
        let sky = TextureEnergy.gradientEnergy(in: flat(8))
        let ceiling = TextureEnergy.gradientEnergy(in: checkerboard())
        XCTAssertGreaterThan(ceiling - sky, 0.2,
                             "structured detail must separate clearly from flat sky")
    }

    /// A *dark* textured surface must still score high — the night-indoor case, where
    /// the room is dim but the ceiling still has geometry.
    func testDarkTexturedSurfaceStillScoresHigh() {
        let darkCeiling = TextureEnergy.gradientEnergy(in: checkerboard(light: 60, dark: 10))
        let nightSky = TextureEnergy.gradientEnergy(in: flat(8))
        XCTAssertGreaterThan(darkCeiling, nightSky + 0.05,
                             "a dim ceiling must still out-score a dim sky")
    }

    // MARK: - Gradients vs. texture

    /// A smooth luminance ramp — skyglow brightening toward the horizon — must read as
    /// low energy. A gentle gradient is not texture, and must not be mistaken for it.
    func testSmoothGradientReadsAsLowEnergy() {
        let ramp = makeImage { row, _ in
            let v = UInt8(min(255, row * 3))
            return (v, v, v)
        }
        XCTAssertLessThan(TextureEnergy.gradientEnergy(in: ramp), 0.05,
                          "a smooth ramp is not texture")
    }

    // MARK: - Regions

    /// Half sky, half structure must show up in the region split, mirroring how the
    /// depth metrics report top/bottom.
    func testRegionsSeparateSkyFromStructure() {
        let split = makeImage(height: 64) { row, col in
            if row < 32 { return (8, 8, 8) }                    // top: night sky
            let v: UInt8 = (row + col) % 2 == 0 ? 200 : 40      // bottom: structure
            return (v, v, v)
        }
        let byRegion = TextureEnergy.gradientEnergyByRegion(in: split)
        XCTAssertLessThan(byRegion[.top] ?? 1, 0.02, "top third is flat sky")
        XCTAssertGreaterThan(byRegion[.bottom] ?? 0, 0.2, "bottom third is textured")
    }

    // MARK: - Degenerate input

    func testTinyImageReturnsZeroRatherThanCrashing() {
        XCTAssertEqual(TextureEnergy.gradientEnergy(in: flat(128)), 0.0, accuracy: 0.001)
        let tiny = makeImage(width: 2, height: 2) { _, _ in (10, 10, 10) }
        XCTAssertEqual(TextureEnergy.gradientEnergy(in: tiny), 0.0)
    }
}
#endif
