// VideoRecordingViewModel.swift
// AVCaptureSession lifecycle, 30-second countdown, prompt sequencing,
// interruption detection, pre-flight checks, and temp-file management.
// Sky_App_Workflow.md S-VER-03/04/08; Tech Spec §8.1/§8.4.
// All AVFoundation calls are delegated to CaptureController so unit tests
// can inject a mock without a real device.
// Phase 8: SensorRecorder runs concurrently during the 30-second window.

import AVFoundation
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Capture abstraction (testability seam)

protocol CaptureController: AnyObject {
    var isRunning: Bool { get }
    /// The active video capture device, or nil before session configuration / in tests.
    var captureDevice: AVCaptureDevice? { get }
    func configure(preset: AVCaptureSession.Preset, completion: @escaping (Result<Void, Error>) -> Void)
    func startRunning()
    func stopRunning()
    func startRecording(to url: URL, delegate: AVCaptureFileOutputRecordingDelegate)
    func stopRecording()
    func makePreviewSession() -> AVCaptureSession?
}

final class RealCaptureController: CaptureController {
    private let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()

    var isRunning: Bool { session.isRunning }

    var captureDevice: AVCaptureDevice? {
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first { $0.device.hasMediaType(.video) }?.device
    }

    func configure(preset: AVCaptureSession.Preset, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = preset

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                completion(.failure(CaptureError.cameraUnavailable))
                return
            }
            self.session.addInput(input)

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            completion(.success(()))
        }
    }

    func startRunning() { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    func stopRunning()  { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() } }

    func startRecording(to url: URL, delegate: AVCaptureFileOutputRecordingDelegate) {
        output.startRecording(to: url, recordingDelegate: delegate)
    }
    func stopRecording() { output.stopRecording() }

    func makePreviewSession() -> AVCaptureSession? { session }
}

enum CaptureError: Error { case cameraUnavailable }

// MARK: - ViewModel

@MainActor
final class VideoRecordingViewModel: NSObject, ObservableObject {

    // MARK: State

    enum RecordingState: Equatable {
        case idle
        case requestingCamera
        case recording
        case interrupted
        case finished(URL, SensorReading)

        static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.requestingCamera, .requestingCamera),
                 (.recording, .recording), (.interrupted, .interrupted): return true
            case (.finished(let a1, let a2), .finished(let b1, let b2)):
                return a1 == b1 && a2 == b2
            default: return false
            }
        }
    }

    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var currentPromptIndex: Int = 0
    @Published var showCancelConfirmation: Bool = false
    @Published private(set) var storageWarning: Bool = false
    @Published private(set) var batteryWarning: Bool = false

    // MARK: Prompt schedule

    struct Prompt {
        let triggerSecond: Int
        let text: String
    }

    let prompts: [Prompt] = [
        Prompt(triggerSecond: 0,  text: "Hold steady, point your camera up."),
        Prompt(triggerSecond: 6,  text: "Now slowly look around."),
        Prompt(triggerSecond: 14, text: "Point at the sky for 5 seconds."),
        Prompt(triggerSecond: 22, text: "Last bit — show where you are."),
    ]

    var currentPromptText: String { prompts[currentPromptIndex].text }

    // MARK: Constants

    private let recordingDuration = 30
    private let minimumFreeDiskBytes: Int64 = 200 * 1_024 * 1_024
    private let lowBatteryThreshold: Float = 0.05

    // MARK: Internals

    private let captureController: CaptureController
    private var sensorRecorder: SensorRecorder?
    private var outputURL: URL?
    private var timerCancellable: AnyCancellable?
    private var interruptionObserver: NSObjectProtocol?

    // MARK: Init

    init(captureController: CaptureController = RealCaptureController()) {
        self.captureController = captureController
    }

    /// The live capture session for the preview layer, or nil before configuration
    /// (and in unit tests with a mock controller). Exposed so the view can host an
    /// AVCaptureVideoPreviewLayer without reaching into the private controller.
    var previewSession: AVCaptureSession? { captureController.makePreviewSession() }

    // MARK: Pre-flight

    /// Returns false if storage is critically low (blocking). Sets batteryWarning
    /// if battery is low (advisory — caller decides whether to proceed).
    func preflight() -> Bool {
        // Storage check
        let tmpURL = FileManager.default.temporaryDirectory
        if let values = try? tmpURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage,
           capacity < minimumFreeDiskBytes {
            storageWarning = true
            return false
        }

        // Battery check (advisory)
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false
        if level >= 0 && level < lowBatteryThreshold {
            batteryWarning = true
        }
        #endif

        return true
    }

    // MARK: Session lifecycle

    func startSession() async {
        guard preflight() else { return }
        recordingState = .requestingCamera

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("verification_\(UUID().uuidString).mov")
        outputURL = url

        await withCheckedContinuation { continuation in
            captureController.configure(preset: .hd1920x1080) { [weak self] result in
                guard let self else { continuation.resume(); return }
                Task { @MainActor in
                    switch result {
                    case .success:
                        self.registerInterruptionObserver()
                        self.captureController.startRunning()
                        // Small pause so the session is fully running before recording
                        try? await Task.sleep(for: .milliseconds(300))
                        // Start sensor recorder concurrently with video (Tech Spec §8)
                        let recorder = SensorRecorder(captureDevice: self.captureController.captureDevice)
                        self.sensorRecorder = recorder
                        recorder.start()
                        self.captureController.startRecording(to: url, delegate: self)
                        self.startCountdownTimer()
                        self.recordingState = .recording
                    case .failure:
                        self.recordingState = .idle
                    }
                    continuation.resume()
                }
            }
        }
    }

    func stopSession() {
        sensorRecorder?.stopAndDiscard()
        sensorRecorder = nil
        timerCancellable?.cancel()
        timerCancellable = nil
        unregisterInterruptionObserver()
        captureController.stopRunning()
    }

    // MARK: Countdown timer

    func startCountdownTimer() {
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?._tick() }
    }

    /// Internal tick — exposed as `internal` so unit tests can drive it directly.
    func _tick() {
        guard recordingState == .recording else { return }
        elapsedSeconds += 1

        // Update prompt index
        for (index, prompt) in prompts.enumerated().reversed() {
            if elapsedSeconds >= prompt.triggerSecond {
                currentPromptIndex = index
                break
            }
        }

        if elapsedSeconds >= recordingDuration {
            timerCancellable?.cancel()
            timerCancellable = nil
            captureController.stopRecording()
        }
    }

    // MARK: Cancel

    func requestCancel() {
        showCancelConfirmation = true
        captureController.stopRunning()
    }

    func confirmCancel() {
        showCancelConfirmation = false
        sensorRecorder?.stopAndDiscard()
        sensorRecorder = nil
        timerCancellable?.cancel()
        timerCancellable = nil
        deletePartialFile()
        recordingState = .idle
    }

    func resumeAfterCancelDismissed() {
        showCancelConfirmation = false
        captureController.startRunning()
    }

    // MARK: Interruption

    private func registerInterruptionObserver() {
        // AVCaptureSession posts on arbitrary queues; dispatch to MainActor.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureController.makePreviewSession(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.recordingState == .recording else { return }
                self.timerCancellable?.cancel()
                self.timerCancellable = nil
                self.sensorRecorder?.stopAndDiscard()
                self.sensorRecorder = nil
                self.captureController.stopRunning()
                self.deletePartialFile()
                self.recordingState = .interrupted
            }
        }
    }

    private func unregisterInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    // MARK: File cleanup

    private func deletePartialFile() {
        guard let url = outputURL else { return }
        try? FileManager.default.removeItem(at: url)
        outputURL = nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                // Recording ended with an error (e.g. interrupted mid-file).
                _ = error
                self.deletePartialFile()
                if self.recordingState != .interrupted {
                    self.recordingState = .interrupted
                }
            } else {
                let reading = self.sensorRecorder?.stop() ?? .unavailable
                self.sensorRecorder = nil
                self.recordingState = .finished(outputFileURL, reading)
            }
        }
    }
}
