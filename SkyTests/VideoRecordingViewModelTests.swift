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

    private(set) var configureCallCount = 0

    func configure(preset: AVCaptureSession.Preset, completion: @escaping (Result<Void, Error>) -> Void) {
        configureCallCount += 1
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
        guard let recordingDelegate, let url = recordingURL else { return }
        recordingDelegate.fileOutput(
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
        // `_primeForTesting` stands in for startSession(), which needs real
        // camera authorization. Without it `_tick()` no-ops on its
        // `recordingState == .recording` guard.
        vm._primeForTesting()
        vm.startCountdownTimer()
        XCTAssertEqual(vm.elapsedSeconds, 0, "Elapsed seconds should start at 0")
    }

    /// `_tick()` must do nothing outside a recording — this is the guard that
    /// made the tests below silently pass-through before they were primed.
    func testTickIsIgnoredWhenNotRecording() {
        for _ in 0..<30 { vm._tick() }
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertFalse(mock.stopRecordingCalled)
    }

    // MARK: Stops at 30 seconds

    func testRecordingStopsAt30Seconds() {
        vm._primeForTesting()
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

        // The VM deletes its own private `outputURL`, which only startSession()
        // sets — priming it is what makes confirmCancel() reach the file.
        // (Setting it on the mock alone left the VM's URL nil, so the delete
        // was a silent no-op and this assertion could never have passed.)
        vm._primeForTesting(outputURL: tempURL)

        vm.confirmCancel()

        // File must be gone
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempURL.path),
            "Partial video should be deleted on cancel"
        )
    }

    // MARK: Prompts advance on schedule

    func testPromptsAdvanceOnSchedule() {
        vm._primeForTesting()
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

    // MARK: Retry / reset

    /// The reported bug: tapping "Try again" after a failed verification showed the
    /// *last* prompt ("Last bit — show where you are.") over a countdown reading 0
    /// and an empty ring, instead of restarting the recording.
    ///
    /// The coordinator owns one view model for the whole flow, so the second
    /// attempt inherited `elapsedSeconds == 30` and `currentPromptIndex == 3` from
    /// the first. Every existing test above starts from `_primeForTesting`, which
    /// zeroes exactly these two — which is precisely why none of them caught it.
    func testResetReturnsToTheFirstPromptAndAFullCountdown() {
        vm._primeForTesting()
        vm.startCountdownTimer()
        for _ in 0..<30 { vm._tick() }

        // Precondition: this is the state a completed attempt leaves behind.
        XCTAssertEqual(vm.elapsedSeconds, 30)
        XCTAssertEqual(vm.currentPromptIndex, 3)
        XCTAssertEqual(vm.currentPromptText, "Last bit — show where you are.")

        vm.reset()

        XCTAssertEqual(vm.elapsedSeconds, 0, "countdown must read 30, not 0")
        XCTAssertEqual(vm.currentPromptIndex, 0)
        XCTAssertEqual(vm.currentPromptText, "Hold steady, point your camera up.")
        XCTAssertEqual(vm.recordingState, .idle)
    }

    /// After a reset the timer must actually run again. Before the fix the first
    /// tick of a retry started from 30, immediately tripped the `>= 30` auto-stop,
    /// and produced a one-second clip.
    func testResetAllowsAFullSecondAttempt() {
        vm._primeForTesting()
        vm.startCountdownTimer()
        for _ in 0..<30 { vm._tick() }
        vm.reset()

        // Second attempt.
        vm._primeForTesting()
        vm.startCountdownTimer()
        for _ in 0..<6 { vm._tick() }

        XCTAssertEqual(vm.elapsedSeconds, 6, "the retry must count from zero")
        XCTAssertEqual(vm.currentPromptIndex, 1, "prompts must re-sequence from the start")
    }

    /// A retry must not leave the abandoned attempt's video on disk — verification
    /// footage is deleted immediately, pass or fail (CLAUDE.md privacy invariant).
    func testResetDeletesThePartialFile() throws {
        try Data("partial".utf8).write(to: tempURL)
        vm._primeForTesting(outputURL: tempURL)

        vm.reset()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempURL.path),
            "an abandoned attempt's video must not survive the retry"
        )
    }

    /// The other half of the bug lived in `RealCaptureController`: it re-added a
    /// video input to a session that already had one, `canAddInput` returned false,
    /// and the retry failed with `cameraUnavailable` while `makePreviewSession()`
    /// still handed out the stale session — a preview layer over a dead session.
    ///
    /// The real controller needs hardware, so what is asserted here is the property
    /// that matters and that holds in every environment: configuring twice gives
    /// the same answer as configuring once. On the simulator both calls fail (no
    /// camera); on a device both succeed. A non-idempotent implementation is the
    /// only way to get two different outcomes.
    func testRealCaptureControllerConfigureIsIdempotent() {
        let controller = RealCaptureController()

        let first = expectation(description: "first configure")
        var firstSucceeded = false
        controller.configure(preset: .hd1920x1080) { result in
            firstSucceeded = (try? result.get()) != nil
            first.fulfill()
        }
        wait(for: [first], timeout: 5)

        let second = expectation(description: "second configure")
        var secondSucceeded = false
        controller.configure(preset: .hd1920x1080) { result in
            secondSucceeded = (try? result.get()) != nil
            second.fulfill()
        }
        wait(for: [second], timeout: 5)

        XCTAssertEqual(
            firstSucceeded, secondSucceeded,
            "re-configuring an already-configured session must not change the outcome"
        )
    }
}
