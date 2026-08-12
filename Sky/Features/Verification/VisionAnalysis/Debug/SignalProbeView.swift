// SignalProbeView.swift
// SPIKE HUD — surfaces the candidate night-sky signals as live numbers so they can be
// compared across the eight-scene matrix (indoor/outdoor × day/night, plus canopy,
// warehouse, screen-showing-sky, and window).
//
// The code here is scaffolding. The deliverable is the table of numbers it produces.
//
// ⚠️ DEBUG ONLY — reachable solely from DebugMenuView, which is itself #if DEBUG and
// behind the 7-tap unlock. Nothing is written to disk and no user outcome changes.

#if DEBUG
import AVFoundation
import SwiftUI

struct SignalProbeView: View {
    @StateObject private var probe = DepthProbeSession()

    @State private var devices: [DepthDeviceReport] = []
    @State private var coexistence: DepthCoexistenceReport?
    @State private var sceneLabel = "1-indoor-ceiling-day"

    /// The matrix from the plan. Scene 2 first on a non-LiDAR device: if stereo depth is
    /// dead at night, `farOrUnknown` cannot separate an indoor ceiling from open sky and
    /// the depth premise collapses — better to learn that in an evening than a week.
    private let scenes = [
        "1-indoor-ceiling-day",
        "2-indoor-ceiling-night",
        "3-open-sky-day",
        "4-open-sky-night",
        "5-tree-canopy",
        "6-warehouse-high-ceiling",
        "7-screen-showing-sky",
        "8-window-with-sky",
    ]

    var body: some View {
        List {
            capabilitySection
            coexistenceSection
            if probe.isRunning { liveSection }
            controlSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Signal probe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            devices = DepthCapability.surveyBackCameras()
            coexistence = DepthCapability.probeMovieOutputCoexistence()
        }
        .onDisappear { probe.stop() }
    }

    // MARK: - Capability

    private var capabilitySection: some View {
        Section {
            deviceRows
        } header: {
            Text("Devices (R6 — coverage)")
        }
    }

    /// Extracted behind an explicit @ViewBuilder: a `ForEach` over `Identifiable` data
    /// directly inside `Section` lets Swift resolve the `Table` overload of
    /// `Section(content:header:)` instead of the `View` one, which fails to compile.
    @ViewBuilder
    private var deviceRows: some View {
        if devices.isEmpty {
            Text("No back cameras found. On the Simulator this is expected — depth needs hardware.")
                .skyText(.caption, color: SkyColor.inkSoft)
        } else {
            ForEach(devices, id: \.uniqueID) { device in
                VStack(alignment: .leading, spacing: SkySpacing.s1) {
                    Text(device.localizedName)
                        .skyText(.label, color: SkyColor.ink)
                    Text(device.deviceType)
                        .skyText(.caption, color: SkyColor.inkSoft)
                    if device.supportsDepth {
                        Text("\(device.depthCapableFormatCount)/\(device.totalFormatCount) formats carry depth · "
                             + "\(device.depthDimensions ?? "—") \(device.depthPixelFormat ?? "")")
                            .skyText(.caption, color: SkyColor.mossGreenAction)
                    } else {
                        Text("no depth formats")
                            .skyText(.caption, color: SkyColor.coralStreak)
                    }
                }
                .padding(.vertical, SkySpacing.s1)
            }
        }
    }

    // MARK: - Coexistence

    private var coexistenceSection: some View {
        Section {
            if let report = coexistence {
                row("device", report.deviceName)
                row("canAddOutput(depth)", report.canAddDepthOutputToMovieSession ? "YES" : "NO")
                row("video dims", "\(report.videoDimensionsBefore) → \(report.videoDimensionsAfter)")
                row("sessionPreset", report.sessionPresetAfter)
                Text(report.notes)
                    .skyText(.caption, color: SkyColor.inkSoft)
            } else {
                Text("Probing…").skyText(.caption, color: SkyColor.inkSoft)
            }
        } header: {
            Text("Movie + depth coexistence (R3/R4)")
        }
    }

    // MARK: - Live metrics

    private var liveSection: some View {
        Section {
            if let m = probe.latest {
                row("far full", pct(m.far(.full)))
                row("far top / bottom", "\(pct(m.far(.top)))  /  \(pct(m.far(.bottom)))")
                row("far left / right", "\(pct(m.far(.left)))  /  \(pct(m.far(.right)))")
                row("valid", pct(m.validFraction))
                row("nan / zero", "\(pct(m.nanFraction))  /  \(pct(m.zeroFraction))")
                row("median / p90", String(format: "%.2f / %.2f", m.medianValid, m.p90Valid))
                row("buffer", "\(m.width)x\(m.height)")
                row("accuracy / quality", "\(probe.accuracy) / \(probe.quality)")

                // R5: filtering interpolates over the holes we are measuring. If this
                // ever reads "ON", discard the run — the numbers are meaningless.
                HStack {
                    Text("filtering").skyText(.caption, color: SkyColor.inkSoft)
                    Spacer()
                    Text(probe.isFiltered ? "ON — DISCARD RUN" : "off")
                        .skyText(.caption,
                                 color: probe.isFiltered ? SkyColor.coralStreak : SkyColor.mossGreenAction)
                }
            } else {
                Text("Waiting for the first depth frame…")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }

            if probe.runMaxFarFull > 0 {
                row("run max / median", "\(pct(probe.runMaxFarFull)) / \(pct(probe.runMedianFarFull))")
            }
        } header: {
            Text("Live (\(probe.frameCount) frames, \(probe.droppedFrames) dropped)")
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        Section {
            Picker("Scene", selection: $sceneLabel) {
                ForEach(scenes, id: \.self) { Text($0).tag($0) }
            }

            if !probe.isRunning {
                Button("Start probe") { probe.start() }
            } else {
                Button(probe.isRecordingRun ? "End run and print" : "Begin 30 s run") {
                    if probe.isRecordingRun {
                        probe.endRun()
                    } else {
                        probe.beginRun(label: sceneLabel)
                    }
                }
                Button("Stop probe", role: .destructive) { probe.stop() }
            }

            Text(probe.status)
                .skyText(.caption, color: SkyColor.inkSoft)
            Text("Results print to the Xcode console tagged [SignalProbe]. Nothing is written to disk.")
                .skyText(.caption, color: SkyColor.inkSoft)
        } header: {
            Text("Run")
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).skyText(.caption, color: SkyColor.inkSoft)
            Spacer()
            Text(value)
                .skyText(.caption, color: SkyColor.ink)
                .monospaced()
        }
    }

    private func pct(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }
}

#Preview("Signal probe") {
    NavigationStack { SignalProbeView() }
}
#endif
