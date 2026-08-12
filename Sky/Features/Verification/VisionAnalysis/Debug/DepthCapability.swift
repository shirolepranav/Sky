// DepthCapability.swift
// SPIKE step 1 — the cheapest, highest-information measurement in the whole exercise.
// Answers three things before any metric code runs:
//
//   R3  Can AVCaptureDepthDataOutput coexist with the AVCaptureMovieFileOutput the
//       production recorder uses? If not, a real integration needs AVAssetWriter, and
//       that is worth knowing on day one rather than after a week of histograms.
//   R4  Does pinning a depth-capable activeFormat change the video? Setting
//       activeFormat implicitly flips sessionPreset to .inputPriority, and depth-capable
//       back formats are often 4:3 while production assumes .hd1920x1080 — so a naive
//       integration would silently re-frame every verification video.
//   R6  What is the real device coverage of depth on the hardware we can test?
//
// ⚠️ DEBUG ONLY. The coexistence probe configures a throwaway session and tears it
// down; it never calls startRunning() and never records a frame to disk.

#if DEBUG
import AVFoundation
import Foundation

/// What one back-facing camera can do.
struct DepthDeviceReport: Identifiable {
    var id: String { uniqueID }
    let uniqueID: String
    let localizedName: String
    let deviceType: String
    let depthCapableFormatCount: Int
    let totalFormatCount: Int

    /// Best depth format found, described for the HUD. Nil when the device has none.
    let bestDepthFormatDescription: String?
    let depthDimensions: String?
    let depthPixelFormat: String?

    var supportsDepth: Bool { depthCapableFormatCount > 0 }
}

/// Outcome of the config-only coexistence probe.
struct DepthCoexistenceReport {
    let deviceName: String
    let canAddDepthOutputToMovieSession: Bool
    let videoDimensionsBefore: String
    let videoDimensionsAfter: String
    let sessionPresetAfter: String
    let notes: String
}

enum DepthCapability {

    /// Device types worth asking about, most capable first. `.builtInWideAngleCamera` is
    /// included only so the report can say "this phone has no depth" rather than be silent.
    static let candidateTypes: [AVCaptureDevice.DeviceType] = [
        .builtInLiDARDepthCamera,
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
    ]

    // MARK: - Capability report

    static func surveyBackCameras() -> [DepthDeviceReport] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: candidateTypes,
            mediaType: .video,
            position: .back
        )

        return session.devices.map { device in
            let depthFormats = device.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
            let best = bestDepthFormat(on: device)

            return DepthDeviceReport(
                uniqueID: device.uniqueID,
                localizedName: device.localizedName,
                deviceType: device.deviceType.rawValue,
                depthCapableFormatCount: depthFormats.count,
                totalFormatCount: device.formats.count,
                bestDepthFormatDescription: best.map { describe(format: $0.video) },
                depthDimensions: best.map { dimensions(of: $0.depth.formatDescription) },
                depthPixelFormat: best.map {
                    fourCC(CMFormatDescriptionGetMediaSubType($0.depth.formatDescription))
                }
            )
        }
    }

    /// Highest-resolution depth format available on `device`, paired with its video format.
    static func bestDepthFormat(
        on device: AVCaptureDevice
    ) -> (video: AVCaptureDevice.Format, depth: AVCaptureDevice.Format)? {
        var best: (AVCaptureDevice.Format, AVCaptureDevice.Format)?
        var bestPixels = 0

        for videoFormat in device.formats {
            for depthFormat in videoFormat.supportedDepthDataFormats {
                let dims = CMVideoFormatDescriptionGetDimensions(depthFormat.formatDescription)
                let pixels = Int(dims.width) * Int(dims.height)
                if pixels > bestPixels {
                    bestPixels = pixels
                    best = (videoFormat, depthFormat)
                }
            }
        }
        return best
    }

    /// First back-facing device that can actually produce depth, most capable first.
    static func preferredDepthDevice() -> AVCaptureDevice? {
        for type in candidateTypes where type != .builtInWideAngleCamera {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back),
               bestDepthFormat(on: device) != nil {
                return device
            }
        }
        return nil
    }

    // MARK: - Coexistence probe (configures and tears down; never runs)

    /// Mirrors `RealCaptureController.configure()` — wide-angle input, mic input,
    /// AVCaptureMovieFileOutput, .hd1920x1080 — then asks whether a depth output could
    /// be added, and what pinning a depth format does to the video dimensions.
    static func probeMovieOutputCoexistence() -> DepthCoexistenceReport {
        guard let device = preferredDepthDevice() else {
            return DepthCoexistenceReport(
                deviceName: "none",
                canAddDepthOutputToMovieSession: false,
                videoDimensionsBefore: "—",
                videoDimensionsAfter: "—",
                sessionPresetAfter: "—",
                notes: "No back camera on this device exposes any depth format."
            )
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1920x1080

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return DepthCoexistenceReport(
                deviceName: device.localizedName,
                canAddDepthOutputToMovieSession: false,
                videoDimensionsBefore: "—",
                videoDimensionsAfter: "—",
                sessionPresetAfter: session.sessionPreset.rawValue,
                notes: "Could not add the depth-capable device as an input."
            )
        }
        session.addInput(input)

        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let movieOutput = AVCaptureMovieFileOutput()
        let movieAdded = session.canAddOutput(movieOutput)
        if movieAdded { session.addOutput(movieOutput) }

        let before = dimensions(of: device.activeFormat.formatDescription)

        // The R3 question, in one boolean.
        let depthOutput = AVCaptureDepthDataOutput()
        let canAddDepth = session.canAddOutput(depthOutput)
        if canAddDepth { session.addOutput(depthOutput) }

        // The R4 question: pin a depth-capable format and see what moves.
        var after = before
        if let best = bestDepthFormat(on: device),
           (try? device.lockForConfiguration()) != nil {
            device.activeFormat = best.video
            device.activeDepthDataFormat = best.depth
            after = dimensions(of: device.activeFormat.formatDescription)
            device.unlockForConfiguration()
        }

        var notes: [String] = []
        if !movieAdded { notes.append("movie output could NOT be added") }
        notes.append(canAddDepth
            ? "depth output coexists with movie output"
            : "depth output REJECTED alongside movie output — production would need AVAssetWriter")
        if before != after {
            notes.append("activeFormat changed video dimensions \(before) → \(after)")
        }

        let report = DepthCoexistenceReport(
            deviceName: device.localizedName,
            canAddDepthOutputToMovieSession: canAddDepth,
            videoDimensionsBefore: before,
            videoDimensionsAfter: after,
            sessionPresetAfter: session.sessionPreset.rawValue,
            notes: notes.joined(separator: "; ")
        )

        // Greppable in the Xcode console; DebugMenuView already uses bare print().
        print("[SignalProbe] coexistence device=\(report.deviceName) "
              + "canAddDepth=\(report.canAddDepthOutputToMovieSession) "
              + "dims=\(report.videoDimensionsBefore)->\(report.videoDimensionsAfter) "
              + "preset=\(report.sessionPresetAfter) notes=\(report.notes)")

        session.removeOutput(movieOutput)
        if canAddDepth { session.removeOutput(depthOutput) }
        session.removeInput(input)

        return report
    }

    // MARK: - Formatting

    static func dimensions(of description: CMFormatDescription) -> String {
        let d = CMVideoFormatDescriptionGetDimensions(description)
        return "\(d.width)x\(d.height)"
    }

    static func describe(format: AVCaptureDevice.Format) -> String {
        dimensions(of: format.formatDescription)
    }

    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }

    /// Whether a pixel format carries disparity (inverse depth) rather than metres.
    static func isDisparity(_ code: FourCharCode) -> Bool {
        code == kCVPixelFormatType_DisparityFloat16 || code == kCVPixelFormatType_DisparityFloat32
    }
}
#endif
