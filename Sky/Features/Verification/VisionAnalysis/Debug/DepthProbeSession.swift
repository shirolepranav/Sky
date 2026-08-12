// DepthProbeSession.swift
// SPIKE — a standalone capture session that streams depth and reports metrics live.
//
// Deliberately NOT built on RealCaptureController: the question "what does the depth
// signal look like?" needs a camera pointed at a ceiling and a camera pointed at the
// sky, not a recorded file, a SensorReading, or the decision engine. Keeping it
// separate means the production recording path — and every test that covers it — is
// untouched.
//
// PRIVACY: no AVCaptureMovieFileOutput, no AVAssetWriter, nothing written to disk.
// The CLAUDE.md invariant ("videos deleted right after processing, no upload, ever")
// is satisfied by construction here rather than by a `defer` that has to be correct.
//
// Threading mirrors SensorRecorder: @MainActor throughout, with `nonisolated` delegate
// callbacks hopping back via Task { @MainActor in }.

#if DEBUG
import AVFoundation
import Combine
import Foundation

@MainActor
final class DepthProbeSession: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var latest: DepthFrameMetrics?
    @Published private(set) var isRunning = false
    @Published private(set) var status: String = "Idle"
    @Published private(set) var accuracy: String = "—"
    @Published private(set) var quality: String = "—"
    @Published private(set) var isFiltered = true          // surfaced, not trusted — see below
    @Published private(set) var droppedFrames = 0
    @Published private(set) var frameCount = 0

    /// Run aggregate, mirroring the `maxSkyPixelPercent` convention so the numbers are
    /// directly comparable with the incumbent check.
    @Published private(set) var runMaxFarFull: Double = 0
    @Published private(set) var runMedianFarFull: Double = 0
    @Published private(set) var isRecordingRun = false

    private var runSamples: [Double] = []
    private var runLabel = ""

    // MARK: - Capture

    let session = AVCaptureSession()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let depthQueue = DispatchQueue(label: "sky.depthprobe.depth")
    private var isDisparityFormat = false
    private var lastSampleTime = Date.distantPast

    /// ~5 Hz is plenty for reading numbers off a screen, and keeps the main actor free.
    private let sampleInterval: TimeInterval = 0.2

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        guard let device = DepthCapability.preferredDepthDevice() else {
            status = "No depth-capable back camera on this device. "
                   + "The Simulator has none — run on hardware."
            return
        }
        guard let best = DepthCapability.bestDepthFormat(on: device) else {
            status = "\(device.localizedName) exposes no depth format."
            return
        }

        session.beginConfiguration()

        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            status = "Could not open \(device.localizedName)."
            return
        }
        session.addInput(input)

        guard session.canAddOutput(depthOutput) else {
            session.commitConfiguration()
            status = "Session rejected the depth output."
            return
        }
        session.addOutput(depthOutput)

        // AVCaptureDepthDataOutput.isFilteringEnabled defaults to TRUE and interpolates
        // over exactly the holes this spike is trying to measure. Turning it off is
        // load-bearing; `isFiltered` is published so a run can be discarded if the
        // setting somehow did not take.
        depthOutput.isFilteringEnabled = false
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.setDelegate(self, callbackQueue: depthQueue)

        if let connection = depthOutput.connection(with: .depthData) {
            connection.isEnabled = true
        }

        do {
            try device.lockForConfiguration()
            device.activeFormat = best.video
            device.activeDepthDataFormat = best.depth
            device.unlockForConfiguration()
        } catch {
            session.commitConfiguration()
            status = "Could not pin the depth format: \(error.localizedDescription)"
            return
        }

        let subType = CMFormatDescriptionGetMediaSubType(best.depth.formatDescription)
        isDisparityFormat = DepthCapability.isDisparity(subType)

        session.commitConfiguration()

        status = "\(device.localizedName) · \(DepthCapability.fourCC(subType))"
              + " · \(DepthCapability.dimensions(of: best.depth.formatDescription))"
              + (isDisparityFormat ? " (disparity)" : " (metres)")

        isRunning = true
        Task.detached { [session] in session.startRunning() }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        isRecordingRun = false
        Task.detached { [session] in session.stopRunning() }
    }

    // MARK: - Runs

    /// Begins accumulating for a labelled 30-second observation.
    func beginRun(label: String) {
        runLabel = label
        runSamples.removeAll()
        runMaxFarFull = 0
        runMedianFarFull = 0
        frameCount = 0
        droppedFrames = 0
        isRecordingRun = true
    }

    /// Ends the run and prints one greppable CSV line plus the last histogram.
    func endRun() {
        isRecordingRun = false
        guard !runSamples.isEmpty else {
            print("[SignalProbe] run label=\(runLabel) produced NO depth frames")
            return
        }
        let sorted = runSamples.sorted()
        runMaxFarFull = sorted.last ?? 0
        runMedianFarFull = sorted[sorted.count / 2]
        let p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]

        let m = latest
        print("[SignalProbe] run,label=\(runLabel),frames=\(frameCount),dropped=\(droppedFrames),"
              + "maxFarFull=\(fmt(runMaxFarFull)),medianFarFull=\(fmt(runMedianFarFull)),p90=\(fmt(p90)),"
              + "top=\(fmt(m?.far(.top) ?? 0)),bottom=\(fmt(m?.far(.bottom) ?? 0)),"
              + "left=\(fmt(m?.far(.left) ?? 0)),right=\(fmt(m?.far(.right) ?? 0)),"
              + "valid=\(fmt(m?.validFraction ?? 0)),nan=\(fmt(m?.nanFraction ?? 0)),"
              + "zero=\(fmt(m?.zeroFraction ?? 0)),medianDepth=\(fmt(m?.medianValid ?? 0)),"
              + "accuracy=\(accuracy),quality=\(quality),filtered=\(isFiltered)")
        if let histogram = m?.histogram {
            print("[SignalProbe] histogram label=\(runLabel) \(histogram)")
        }
    }

    private func fmt(_ value: Double) -> String { String(format: "%.4f", value) }

    // MARK: - Ingest

    fileprivate func ingest(_ depthData: AVDepthData) {
        let now = Date()
        guard now.timeIntervalSince(lastSampleTime) >= sampleInterval else { return }
        lastSampleTime = now

        isFiltered = depthData.isDepthDataFiltered
        accuracy = depthData.depthDataAccuracy == .absolute ? "absolute" : "relative"
        quality = depthData.depthDataQuality == .high ? "high" : "low"

        let metrics = DepthMetricsCalculator.metrics(
            from: depthData.depthDataMap,
            isDisparity: isDisparityFormat
        )
        latest = metrics
        frameCount += 1

        if isRecordingRun {
            runSamples.append(metrics.far(.full))
        }
    }

    fileprivate func noteDrop() { droppedFrames += 1 }
}

// MARK: - AVCaptureDepthDataOutputDelegate

extension DepthProbeSession: AVCaptureDepthDataOutputDelegate {

    nonisolated func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        Task { @MainActor [weak self] in
            self?.ingest(depthData)
        }
    }

    nonisolated func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didDrop depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection,
        reason: AVCaptureOutput.DataDroppedReason
    ) {
        // A spike that silently drops most frames looks like a working spike.
        print("[SignalProbe] dropped depth frame, reason=\(reason.rawValue)")
        Task { @MainActor [weak self] in
            self?.noteDrop()
        }
    }
}
#endif
