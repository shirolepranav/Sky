// VideoRecordingViewModelTests.swift
// Phase 7 automated tests (Roadmap Phase 7 → Automated Tests).
// Tests the countdown timer, prompt advancement, cancel file-cleanup, and
// 30-second auto-stop — all without touching real AVFoundation.
// A MockCaptureController is injected via the CaptureController protocol seam.

import AVFoundation
import XCTest
@testable import Sky

// MARK: - Mock capture controller

final class MockCaptureController: CaptureController {
    var isRunning: Bool = false
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var stopRunningCalled = false

    private var recordingDelegate: AVCaptureFileOutputRecordingDelegate?
    private var recordingURL: URL?

    func configure(preset: AVCaptureSession.Preset, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func startRunning()  { isRunning = true }
    func stopRunning()   { isRunning = false; stopRunningCalled = true }

    func startRecording(to url: URL, delegate: AVCaptureFileOutputRecordingDelegate) {
        startRecordingCalled = true
        recordingURL = url
        recordingDelegate = delegate
    }

    func stopRecording() {
        stopRecordingCalled = true
        // Simulate successful file-write by calling the delegate
        guard let delegate, let url = recordingURL else { return }
        delegate.fileOutput(
            AVCaptureMovieFileOutput(),
            didFinishRecordingTo: url,
            from: [],
            error: nil
        )
    }

    func makePreviewSession() -> AVCaptureSession? { nil }
    var captureDevice: AVCaptureDevice? { nil }
}

// MARK: - Tests

@MainActor
final class VideoRecordingViewModelTests: XCTestCase {

    private var mock: MockCaptureController!
    private var vm: VideoRecordingViewModel!
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        mock = MockCaptureController()
        vm = VideoRecordingViewModel(captureController: mock)
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mov")
    }

    override func tearDown() {
        vm.stopSession()
        try? FileManager.default.removeItem(at: tempURL)
        vm = nil
        mock = nil
        tempURL = nil
        super.tearDown()
    }

    // MARK: Timer starts

    func testRecordingStartsTimer() async {
        // Prime recording state manually (startSession needs camera access on device)
        vm.startCountdownTimer()
        XCTAssertEqual(vm.elapsedSeconds, 0, "Elapsed seconds should start at 0")
    }

    // MARK: Stops at 30 seconds

    func testRecordingStopsAt30Seconds() {
        // Put VM into recording state so _tick() runs
        vm.startCountdownTimer()

        // Drive 30 ticks manually
        for _ in 0..<30 { vm._tick() }

        XCTAssertTrue(mock.stopRecordingCalled, "stopRecording should be called at 30 seconds")
        XCTAssertEqual(vm.elapsedSeconds, 30)
    }

    // MARK: Cancel deletes file

    func testCancelDeletesFile() throws {
        // Create a real temp file to simulate a partial recording
        try Data("partial".utf8).write(to: tempURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Inject the URL into the VM via a partial recording start
        // (we test the delete logic directly via confirmCancel after setting outputURL)
        // Use internal _tick after manually wiring up the output URL via startSession simulation
        mock.startRecording(to: tempURL, delegate: vm)

        vm.confirmCancel()

        // File must be gone
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempURL.path),
            "Partial video should be deleted on cancel"
        )
    }

    // MARK: Prompts advance on schedule

    func testPromptsAdvanceOnSchedule() {
        vm.startCountdownTimer()

        // 0–5s → prompt 0
        for _ in 0..<5 { vm._tick() }
        XCTAssertEqual(vm.currentPromptIndex, 0, "Prompt 0 should show at 0–5s")

        // 6s → prompt 1
        vm._tick()
        XCTAssertEqual(vm.currentPromptIndex, 1, "Prompt 1 should show at 6s")

        // 7–13s → still prompt 1
        for _ in 0..<7 { vm._tick() }
        XCTAssertEqual(vm.currentPromptIndex, 1, "Prompt 1 should persist through 13s")

        // 14s → prompt 2
        vm._tick()
        XCTAssertEqual(vm.currentPromptIndex, 2, "Prompt 2 should show at 14s")

        // 22s → prompt 3
        for _ in 0..<8 { vm._tick() }
        XCTAssertEqual(vm.currentPromptIndex, 3, "Prompt 3 should show at 22s")
    }
}
