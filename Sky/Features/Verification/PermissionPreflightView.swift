// PermissionPreflightView.swift
// S-VER-02 — Checks camera/mic/location authorization and routes accordingly.
// S-PERM-04 rationale is embedded as a private view shown before the first
// permission request.
// Sky_App_Workflow.md §Part 2 S-VER-02, S-PERM-04.

import AVFoundation
import CoreLocation
import SwiftUI

// MARK: - ViewModel

@MainActor
final class PermissionPreflightViewModel: ObservableObject {
    enum PermissionStatus { case granted, denied, notDetermined }

    @Published var camera: PermissionStatus = .notDetermined
    @Published var microphone: PermissionStatus = .notDetermined
    @Published var location: PermissionStatus = .notDetermined

    var allGranted: Bool {
        camera == .granted && microphone == .granted && location == .granted
    }

    private let locationManager = CLLocationManager()

    func refresh() {
        camera    = map(AVCaptureDevice.authorizationStatus(for: .video))
        microphone = map(AVCaptureDevice.authorizationStatus(for: .audio))
        location  = mapLocation(locationManager.authorizationStatus)
    }

    private func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    private func mapLocation(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    func requestAll() async {
        await AVCaptureDevice.requestAccess(for: .video)
        await AVCaptureDevice.requestAccess(for: .audio)
        locationManager.requestWhenInUseAuthorization()
        // Give CLLocationManager a moment to update (it's callback-based)
        try? await Task.sleep(for: .milliseconds(500))
        refresh()
    }
}

// MARK: - Main preflight view

struct PermissionPreflightView: View {
    var onAllGranted: () -> Void
    @StateObject private var vm = PermissionPreflightViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                NimbusView(state: .fluffyWhite, size: 160)

                Text("Three quick permissions.")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("Sky needs camera, microphone, and location to verify you're outside.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                VStack(spacing: SkySpacing.s3) {
                    PermissionRow(icon: "camera.fill",
                                  label: "Camera",
                                  status: vm.camera,
                                  identifier: "verification.permRow.camera")
                    PermissionRow(icon: "mic.fill",
                                  label: "Microphone",
                                  status: vm.microphone,
                                  identifier: "verification.permRow.microphone")
                    PermissionRow(icon: "location.fill",
                                  label: "Location",
                                  status: vm.location,
                                  identifier: "verification.permRow.location")
                }
                .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                if vm.allGranted {
                    SkyPrimaryButton("Continue") { onAllGranted() }
                        .padding(.horizontal, SkyLayout.screenMargin)
                } else if anyDenied {
                    SkyPrimaryButton("Open Settings") { openSettings() }
                        .padding(.horizontal, SkyLayout.screenMargin)
                } else {
                    SkyPrimaryButton("Grant Permissions") {
                        Task { await vm.requestAll() }
                    }
                    .padding(.horizontal, SkyLayout.screenMargin)
                }

                Spacer(minLength: SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.permissionPreflight")
        .task {
            vm.refresh()
            // Auto-advance if permissions were already granted (< 300ms skip)
            if vm.allGranted { onAllGranted() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                vm.refresh()
                if vm.allGranted { onAllGranted() }
            }
        }
    }

    private var anyDenied: Bool {
        vm.camera == .denied || vm.microphone == .denied || vm.location == .denied
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let icon: String
    let label: String
    let status: PermissionPreflightViewModel.PermissionStatus
    let identifier: String

    var body: some View {
        HStack(spacing: SkySpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(SkyColor.mossGreen)
                .frame(width: 24)

            Text(label)
                .skyText(.body)

            Spacer()

            Image(systemName: statusIcon)
                .font(.system(size: 17))
                .foregroundColor(statusColor)
        }
        .padding(SkySpacing.s4)
        .background(SkyColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: SkyRadius.cardSecondary))
        .overlay(
            RoundedRectangle(cornerRadius: SkyRadius.cardSecondary)
                .strokeBorder(SkyColor.divider, lineWidth: 1)
        )
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(label): \(statusLabel)")
    }

    private var statusIcon: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied:  return "lock.fill"
        case .notDetermined: return "circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return SkyColor.mossGreen
        case .denied:  return SkyColor.coralStreak
        case .notDetermined: return SkyColor.inkMuted
        }
    }

    private var statusLabel: String {
        switch status {
        case .granted: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "not determined"
        }
    }
}

#Preview("S-VER-02 — all granted") {
    PermissionPreflightView(onAllGranted: {})
}

#Preview("S-VER-02 dark") {
    PermissionPreflightView(onAllGranted: {})
        .preferredColorScheme(.dark)
}
