// TextureEnergy.swift
// SPIKE — daylight-independent "is this surface smooth?" signal.
//
// Sky is smooth at any light level: clear blue, flat overcast, or black night, the
// local gradient is near zero. Ceilings are not — vents, beams, fixtures, corners and
// edges all produce strong local gradients even in a dim room.
//
// This is the hedge against the plan's R1 risk. If stereo depth turns out to be dead
// at night (leaving depth a LiDAR-only signal), this is the only remaining candidate
// that runs on *every* iOS 17 device. It is also the cheapest to adopt: it takes a
// CGImage, so it drops straight into VisionAnalyzer's existing frame loop with no
// capture-pipeline changes at all.
//
// ⚠️ DEBUG ONLY, and not wired into anything. Measured, not enforced.
//
// Pure static functions in the shape of SkyPixelCounter, for the same reason:
// testability without a camera.

#if DEBUG
import CoreGraphics
import Foundation

enum TextureEnergy {

    /// Mean absolute luminance gradient over `region`, normalised to 0...1.
    ///
    /// Uses a cheap forward difference (right and down neighbours) rather than a full
    /// Sobel — at spike stage the question is whether the *separation* exists, not
    /// whether the operator is optimal.
    ///
    /// Subsamples every 2nd row and column: enough for a mean over a 480×270 frame,
    /// and 4× cheaper. Returns 0 for images too small to have neighbours.
    static func gradientEnergy(in image: CGImage, region: DepthRegion = .full) -> Double {
        guard let data = luminance(of: image) else { return 0 }
        let width = image.width
        let height = image.height
        guard width > 2, height > 2 else { return 0 }

        let bounds = pixelBounds(for: region, width: width, height: height)

        var total = 0.0
        var samples = 0

        var row = bounds.minY
        while row < bounds.maxY - 1 {
            var col = bounds.minX
            while col < bounds.maxX - 1 {
                let here = data[row * width + col]
                let right = data[row * width + (col + 1)]
                let down = data[(row + 1) * width + col]
                total += abs(here - right) + abs(here - down)
                samples += 1
                col += 2
            }
            row += 2
        }

        guard samples > 0 else { return 0 }
        // Two differences per sample, each already 0...1.
        return min(1.0, total / Double(samples) / 2.0)
    }

    /// Same measurement expressed per region, so a frame that is half sky and half
    /// ground can be read the way the depth metrics are.
    static func gradientEnergyByRegion(in image: CGImage) -> [DepthRegion: Double] {
        var out: [DepthRegion: Double] = [:]
        for region in DepthRegion.allCases {
            out[region] = gradientEnergy(in: image, region: region)
        }
        return out
    }

    // MARK: - Private

    private static func pixelBounds(
        for region: DepthRegion, width: Int, height: Int
    ) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        switch region {
        case .full:   return (0, width, 0, height)
        case .top:    return (0, width, 0, height / 3)
        case .bottom: return (0, width, height - height / 3, height)
        case .left:   return (0, width / 3, 0, height)
        case .right:  return (width - width / 3, width, 0, height)
        }
    }

    /// Rec. 601 luma, normalised 0...1, in a tightly packed width × height array.
    private static func luminance(of image: CGImage) -> [Double]? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var out = [Double](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            let r = Double(pixels[index * 4]) / 255.0
            let g = Double(pixels[index * 4 + 1]) / 255.0
            let b = Double(pixels[index * 4 + 2]) / 255.0
            out[index] = 0.299 * r + 0.587 * g + 0.114 * b
        }
        return out
    }
}
#endif
