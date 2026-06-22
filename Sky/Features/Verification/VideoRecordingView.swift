// VideoRecordingView.swift
// S-VER-03 — Full-bleed camera preview with 30-second countdown ring,
// timed prompts, recording dot, and cancel button.
// S-VER-04 — Cancel confirmation sheet (embedded).
// Sky_App_Workflow.md §Part 2 S-VER-03/04; Tech Spec §8.1.

import AVFoundation
import SwiftUI

struct VideoRecordingView: View {
    @ObservedObject var vm: VideoRecordingViewModel
    var onFinished: (URL, SensorReading) -> Void
    var onCancelled: () -> Void
    var onInterrupted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Camera preview (UIKit bridge, iOS only)
            #if canImport(UIKit)
            if let session = vm.previewSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Color.black.ignoresSafeArea()
            }
            #else
            Color.black.ignoresSafeArea()
            #endif

            // Overlay layer
            VStack {
                // Top: countdown ring
                ZStack {
                    SkyProgressRing(
                        progress: 1.0 - Double(vm.elapsedSeconds) / 30.0,
                        accent: .white,
                        lineWidth: 6
                    )
                    .frame(width: 80, height: 80)

                    Text("\(30 - vm.elapsedSeconds)")
                        .skyText(.titleM)
                        .foregroundColor(.white)
                }
                .padding(.top, SkySpacing.s8)
                .modifier(ReduceMotionTransaction(reduce: reduceMotion))

                Spacer()

                // Mid: prompt card
                promptCard
                    .padding(.horizontal, SkySpacing.s6)
                    .animation(.easeInOut(duration: 0.4), value: vm.currentPromptIndex)
                    .transition(.opacity)

                Spacer()

                // Bottom: recording indicator + cancel
                HStack {
                    recordingDot
                        .padding(.leading, SkySpacing.s6)
                    Spacer()
                    cancelButton
                        .padding(.trailing, SkySpacing.s6)
                }
                .padding(.bottom, SkySpacing.s8)
            }
        }
        // S-VER-04 cancel confirmation sheet
        .confirmationDialog(
            "Stop recording?",
            isPresented: $vm.showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                vm.confirmCancel()
                onCancelled()
            }
            Button("Keep going", role: .cancel) {
                vm.resumeAfterCancelDismissed()
            }
        } message: {
            Text("You'll need to start over.")
        }
        // Low storage toast (non-blocking)
        .overlay(alignment: .bottom) {
            if vm.storageWarning {
                storageWarningBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, SkySpacing.s10)
            }
        }
        // Low battery alert (advisory — user may proceed)
        .alert("Battery is low", isPresented: Binding(
            get: { vm.batteryWarning },
            set: { _ in }
        )) {
            Button("Continue") { /* advisory — dismiss and proceed */ }
            Button("Cancel", role: .cancel) {
                vm.confirmCancel()
                onCancelled()
            }
        } message: {
            Text("Recording may stop unexpectedly. Plug in or continue at your own risk.")
        }
        // State routing
        .onChange(of: vm.recordingState) { _, state in
            switch state {
            case .finished(let url, let reading): onFinished(url, reading)
            case .interrupted: onInterrupted()
            default: break
            }
        }
        // VoiceOver prompt announcements
        .onChange(of: vm.currentPromptIndex) { _, _ in
            UIAccessibility.post(
                notification: .announcement,
                argument: vm.currentPromptText
            )
        }
        .task { await vm.startSession() }
        .onDisappear { vm.stopSession() }
        .accessibilityIdentifier("verification.recording")
        .navigationBarHidden(true)
    }

    // MARK: Sub-views

    private var promptCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: SkySpacing.s1) {
                Text("Now")
                    .skyText(.overline, color: .white.opacity(0.7))
                Text(vm.currentPromptText)
                    .skyText(.headline)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(SkySpacing.s4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SkyRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vm.currentPromptText)
    }

    private var recordingDot: some View {
        Circle()
            .fill(SkyColor.coralStreak)
            .frame(width: 10, height: 10)
            .opacity(reduceMotion ? 1 : 1)
            .modifier(PulsingModifier(active: !reduceMotion))
    }

    private var cancelButton: some View {
        Button(action: vm.requestCancel) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Cancel recording")
    }

    private var storageWarningBanner: some View {
        Text("Free up some space and try again.")
            .skyText(.bodyS)
            .foregroundColor(.white)
            .padding(.horizontal, SkySpacing.s4)
            .padding(.vertical, SkySpacing.s3)
            .background(SkyColor.coralStreak)
            .clipShape(Capsule())
    }
}

// MARK: - Camera preview bridge

#if canImport(UIKit)
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        PreviewUIView(session: session)
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) { fatalError() }
    }
}
#endif

// MARK: - Animation helpers

private struct ReduceMotionTransaction: ViewModifier {
    let reduce: Bool
    func body(content: Content) -> some View {
        if reduce {
            content.transaction { $0.animation = nil }
        } else {
            content
        }
    }
}

private struct PulsingModifier: ViewModifier {
    let active: Bool
    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(active ? opacity : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    opacity = 0.3
                }
            }
    }
}

#Preview("S-VER-03") {
    // Static preview without real camera — shows overlay layout
    ZStack {
        Color.black.ignoresSafeArea()
        VideoRecordingView(
            vm: VideoRecordingViewModel(),
            onFinished: { _, _ in },
            onCancelled: {},
            onInterrupted: {}
        )
    }
}
