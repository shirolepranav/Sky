// MainPlaceholderView.swift
// Temporary post-setup destination until the full Today tab (S-TODAY-01) ships
// in Phase 11. Holds the Phase 1 regression path (DesignSystemPreviewScreen).
//
// Phase 5 addition: shows a minimal status banner ("Sky is watching / paused")
// driven by DeviceActivityService.isMonitoring, and kicks off monitoring on
// first appear. The full S-TODAY-02 banner variants (verified, blocked, etc.)
// and Nimbus/ring layout are implemented in Phase 11.

import SwiftUI

struct MainPlaceholderView: View {
    @EnvironmentObject private var deviceActivity: DeviceActivityService
    @State private var showingPreview = false

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s8) {
                NimbusView(state: .sunny, size: 180)

                // Minimal S-TODAY-02 status banner (data layer only — Phase 5).
                SkyCard {
                    HStack(spacing: SkySpacing.s2) {
                        Circle()
                            .fill(deviceActivity.isMonitoring
                                  ? SkyColor.mossGreen
                                  : SkyColor.cloudGrey)
                            .frame(width: 8, height: 8)
                        Text(deviceActivity.isMonitoring
                             ? "Sky is watching."
                             : "Sky is paused.")
                            .skyText(.body)
                        Spacer()
                    }
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .accessibilityIdentifier("today.statusBanner")
                .accessibilityLabel(
                    deviceActivity.isMonitoring ? "Sky is watching." : "Sky is paused."
                )

                SkySecondaryButton("Design system preview") {
                    showingPreview = true
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .accessibilityIdentifier("placeholder.designSystemPreview")
            }
        }
        .accessibilityIdentifier("main.placeholder")
        .onAppear {
            // Safety-net: ensures monitoring is active even if the scenePhase
            // handler in SkyApp missed the transition (e.g. first-ever launch).
            try? deviceActivity.startMonitoring()
        }
        .sheet(isPresented: $showingPreview) {
            DesignSystemPreviewScreen()
        }
    }
}

#Preview("Main placeholder — monitoring active") {
    MainPlaceholderView()
        .environmentObject(DeviceActivityService())
}
